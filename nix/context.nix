# Context constructors — build graph IR from capture data.
#
# `context` builds from raw entries (standalone capture).
# `projectScope` projects a fleet capture onto a single scope subtree,
# producing the graph as seen from that scope — including all child
# entity resolutions (users on a host, hosts in an environment, etc.).
{ graphLib, lib, ... }:
{
  context =
    {
      entries,
      ctxTrace ? [ ],
      pathsByClass ? { },
      name,
      direction ? "LR",
    }:
    let
      graph = graphLib.buildGraph {
        inherit entries ctxTrace direction;
        rootName = name;
      };
    in
    graph // { inherit pathsByClass; };

  # Project a fleet capture onto a scope subtree.
  #
  # Given a fleet capture and a (kind, name) pair identifying a scope,
  # returns a graph IR containing only the entries visible from that
  # scope — the scope itself plus all descendants. This is equivalent
  # to what a standalone capture would produce if it ran the full
  # policy chain, but extracted from the already-resolved fleet data.
  #
  #   hostGraph = projectScope {
  #     inherit fleetCapture;
  #     kind = "host";    # any entity kind
  #     name = "cortex";
  #   };
  #
  #   envGraph = projectScope {
  #     inherit fleetCapture;
  #     kind = "environment";
  #     name = "prod";
  #   };
  projectScope =
    {
      fleetCapture,
      kind,
      name,
      direction ? "LR",
    }:
    let
      inherit (fleetCapture) scopeParent scopeEntityKind entries ctxTrace;
      allScopeIds = builtins.attrNames scopeParent;

      # Extract entity name from a scope ID segment.
      # Scope IDs are comma-separated key=value pairs: "host=cortex,user=sini"
      entityNameFromScope =
        entityKind: scopeId:
        let
          parts = lib.splitString "," scopeId;
          matching = builtins.filter (p: lib.hasPrefix "${entityKind}=" p) parts;
        in
        if matching == [ ] then null
        else lib.removePrefix "${entityKind}=" (builtins.head matching);

      # Find the scope ID for this entity
      targetScopeId = lib.findFirst (
        s: (scopeEntityKind.${s} or null) == kind && entityNameFromScope kind s == name
      ) null allScopeIds;

      # Collect all descendant scope IDs (inclusive)
      descendants =
        rootId:
        let
          children = builtins.filter (s: (scopeParent.${s} or null) == rootId) allScopeIds;
        in
        [ rootId ] ++ lib.concatMap descendants children;

      subtreeScopes = if targetScopeId == null then [ ] else descendants targetScopeId;

      # Build lookup of entityInstance values visible in this subtree
      subtreeInstances = lib.listToAttrs (
        lib.concatMap (
          s:
          let
            ek = scopeEntityKind.${s} or null;
            eName = if ek != null then entityNameFromScope ek s else null;
          in
          lib.optional (ek != null && eName != null) {
            name = "${ek}:${eName}";
            value = true;
          }
        ) subtreeScopes
      );

      # Entries visible from this scope: matching entityInstance or
      # unscoped entries (null instance) that appear in any subtree scope
      filteredEntries = builtins.filter (
        e:
        let inst = e.entityInstance or null; in
        if inst != null then subtreeInstances ? ${inst}
        else subtreeScopes != [ ]
      ) entries;

      # ctxTrace entries for entity kinds present in the subtree
      subtreeKinds = lib.unique (
        lib.filter (x: x != null) (map (s: scopeEntityKind.${s} or null) subtreeScopes)
      );
      filteredCtxTrace = builtins.filter (
        c: lib.elem (c.entityKind or null) subtreeKinds
      ) ctxTrace;

      graph = graphLib.buildGraph {
        entries = filteredEntries;
        ctxTrace = filteredCtxTrace;
        rootName = name;
        inherit direction;
      };
    in
    graph // { pathsByClass = { }; };
}
