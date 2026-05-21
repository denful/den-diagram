# Mindmap renderer (mermaid `mindmap`).
#
# Mermaid mindmap is a pure-tree layout with radial placement around a
# root node. It's a better fit than `graph TD` for hierarchies where
# every child has exactly one parent — no cross-edges, no multiple
# parents. We use it for the provider hierarchy: root = host, branches
# = top-level providers, leaves = provider sub-aspects.
#
# Syntax is indentation-based:
#
#   mindmap
#   root((Host))
#     Provider1
#       sub1
#       sub2
#     Provider2
#       sub3
#
# The renderer assumes the graph is already tree-shaped — typically
# the output of `diag.graph.providersOnly`. Non-tree input (multiple
# parents per node) produces confusing output since mindmap can only
# represent trees.
{
  lib,
  themes,
  renderUtil,
  ...
}:
let
  inherit (renderUtil) renderMermaid;

  # Escape quote characters so mermaid doesn't choke on labels.
  esc = s: lib.replaceStrings [ "\"" ] [ "'" ] s;

  toMindmapMermaidWith =
    {
      theme ? themes.defaultTheme,
      mermaidConfig ? { },
    }:
    graph:
    let
      inherit (graph)
        rootName
        rootId
        nodes
        edges
        ;

      # Build adjacency: parent id -> list of child ids.
      childrenOf = lib.foldl' (
        acc: e: acc // { ${e.from} = (acc.${e.from} or [ ]) ++ [ e.to ]; }
      ) { } edges;

      nodeById = lib.listToAttrs (
        map (n: {
          name = n.id;
          value = n;
        }) nodes
      );

      # Roots: nodes that are not the target of any edge in the tree.
      targetIds = lib.listToAttrs (
        map (e: {
          name = e.to;
          value = true;
        }) edges
      );
      rootNodes = builtins.filter (n: !(targetIds ? ${n.id}) && n.id != rootId) nodes;

      # Recursively render a subtree at the given indentation depth.
      # Indentation step is 2 spaces per level (mermaid mindmap spec).
      renderSubtree =
        depth: id:
        let
          indent = lib.concatStrings (lib.replicate depth "  ");
          node = nodeById.${id} or null;
          label = if node != null then node.label else id;
          children = childrenOf.${id} or [ ];
        in
        [ "${indent}${esc label}" ] ++ lib.concatMap (renderSubtree (depth + 1)) children;

      bodyLines = [ "  root((${esc rootName}))" ] ++ lib.concatMap (r: renderSubtree 2 r.id) rootNodes;
    in
    renderMermaid {
      inherit theme mermaidConfig;
      diagramKind = "mindmap";
    } bodyLines;

  toMindmapMermaid = toMindmapMermaidWith { };
in
{
  inherit toMindmapMermaid toMindmapMermaidWith;
}
