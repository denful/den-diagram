# Treemap diagrams (mermaid treemap-beta).
#
# Syntax: indented hierarchy of quoted labels. Sections are labels without a
# value; leaves have ": N" where N is a numeric weight. Sections nest.
#
# Mapping:
#   per-host: sections = provider aspects (the first element of each
#             sub-aspect's provider chain), leaves = the sub-aspects they
#             expand into. This surfaces where provider expansion actually
#             happens in a host — the "customization points" of the config.
#   fleet:    sections = providers observed anywhere in the fleet, leaves
#             = {sub-aspect, count} showing how many hosts selected each
#             provider option.
{
  lib,
  themes,
  util,
  renderUtil,
}:
let
  inherit (renderUtil) renderMermaid;

  quote = s: "\"${lib.replaceStrings [ "\"" ] [ "\\\"" ] s}\"";

  # --- Per-host treemap: provider groups ---
  toTreemapMermaidWith =
    {
      theme ? themes.defaultTheme,
      mermaidConfig ? { },
    }:
    graph:
    let
      inherit (graph) rootName nodes;

      providerNodes = builtins.filter (n: (n.providerPath or [ ]) != [ ] && n.id != graph.rootId) nodes;

      # Group by top-level provider name (first element of providerPath).
      grouped = lib.foldl' (
        acc: n:
        let
          key = builtins.head n.providerPath;
        in
        acc // { ${key} = (acc.${key} or [ ]) ++ [ n ]; }
      ) { } providerNodes;

      providerSection =
        providerName:
        let
          kids = lib.sort (a: b: a.label < b.label) grouped.${providerName};
          header = quote providerName;
          leafLines = map (n: "    ${quote n.label}: 1") kids;
        in
        [ header ] ++ leafLines;

      providerNames = lib.sort (a: b: a < b) (builtins.attrNames grouped);
    in
    if providerNodes == [ ] then
      renderMermaid
        {
          inherit theme mermaidConfig;
          diagramKind = "treemap-beta";
        }
        [
          "${quote rootName}"
          "    ${quote "(no provider sub-aspects)"}: 1"
        ]
    else
      renderMermaid {
        inherit theme mermaidConfig;
        diagramKind = "treemap-beta";
      } (lib.concatMap providerSection providerNames);

  # --- Fleet treemap ---
  # When enriched fleet data carries per-host provider info, group by
  # provider name and show each sub-aspect with count = number of hosts
  # that selected it. Otherwise fall back to user→hosts layout.
  toFleetTreemapMermaidWith =
    {
      theme ? themes.defaultTheme,
      mermaidConfig ? { },
    }:
    fleet:
    let
      inherit (fleet) relations;
      providerSubAspects = fleet.providerSubAspects or [ ];
      hasProviderData = providerSubAspects != [ ];

      # Group a list of { provider, subAspect, hostName } records by provider.
      groupByProvider =
        items:
        lib.foldl' (
          acc: item: acc // { ${item.provider} = (acc.${item.provider} or [ ]) ++ [ item ]; }
        ) { } items;

      providerGrouped = groupByProvider providerSubAspects;

      # Count selections per sub-aspect.
      countsBySubAspect =
        items:
        lib.foldl' (acc: item: acc // { ${item.subAspect} = (acc.${item.subAspect} or 0) + 1; }) { } items;

      providerSection =
        providerName:
        let
          items = providerGrouped.${providerName};
          counts = countsBySubAspect items;
          sortedSubs = lib.sort (a: b: a < b) (builtins.attrNames counts);
          header = quote providerName;
          leafLines = map (sub: "    ${quote sub}: ${toString counts.${sub}}") sortedSubs;
        in
        [ header ] ++ leafLines;

      # Fallback: user → host sections.
      usersWithHosts =
        let
          byUser = builtins.foldl' (
            acc: rel: acc // { ${rel.from} = (acc.${rel.from} or [ ]) ++ [ rel.to ]; }
          ) { } relations;
        in
        lib.mapAttrsToList (userName: hosts: {
          name = userName;
          hosts = lib.unique hosts;
        }) byUser;

      userSection =
        u:
        let
          header = quote u.name;
          leafLines = map (h: "    ${quote h}: 1") u.hosts;
        in
        [ header ] ++ leafLines;
    in
    if hasProviderData then
      renderMermaid {
        inherit theme mermaidConfig;
        diagramKind = "treemap-beta";
      } (lib.concatMap providerSection (lib.sort (a: b: a < b) (builtins.attrNames providerGrouped)))
    else if relations == [ ] then
      renderMermaid
        {
          inherit theme mermaidConfig;
          diagramKind = "treemap-beta";
        }
        [
          "${quote fleet.flakeName}: 1"
        ]
    else
      renderMermaid {
        inherit theme mermaidConfig;
        diagramKind = "treemap-beta";
      } (lib.concatMap userSection usersWithHosts);

  # --- Fleet provider matrix (mermaid flowchart) ---
  #
  # Bipartite graph of providers ↔ hosts. Each distinct provider-host
  # pairing from `fleet.providerSubAspects` becomes an edge. Answers
  # "which hosts pull which providers?" at a glance — complements
  # fleet-treemap which shows counts per provider.
  toFleetProviderMatrixWith =
    {
      theme ? themes.defaultTheme,
      mermaidConfig ? { },
    }:
    fleet:
    let
      providerSubAspects = fleet.providerSubAspects or [ ];
      pairs = lib.unique (map (item: { inherit (item) provider hostName; }) providerSubAspects);

      sanChars = util.sanitizeChars;

      providers = lib.unique (map (p: p.provider) pairs);
      hosts = lib.unique (map (p: p.hostName) pairs);

      provId = p: "p_${sanChars p}";
      hostId = h: "h_${sanChars h}";

      providerDecl = p: "    ${provId p}[/\"${p}\"\\]:::provider_c";
      hostDecl = h: "    ${hostId h}([\"${h}\"]):::matrixhost_c";
      edgeDecl = pair: "  ${provId pair.provider} --> ${hostId pair.hostName}";
    in
    if pairs == [ ] then
      renderMermaid
        {
          inherit theme mermaidConfig;
          diagramKind = "graph LR";
        }
        [
          "  empty[\"(no provider usage found)\"]"
        ]
    else
      renderMermaid
        {
          inherit theme mermaidConfig;
          diagramKind = "graph LR";
        }
        (
          [ "  subgraph providers[\"Providers\"]" ]
          ++ map providerDecl providers
          ++ [
            "  end"
            ""
            "  subgraph hostsCluster[\"Hosts\"]"
          ]
          ++ map hostDecl hosts
          ++ [
            "  end"
            ""
          ]
          ++ map edgeDecl pairs
          ++ [
            ""
            "  classDef provider_c fill:${theme.nodeBg},stroke:${theme.nodeBorder},color:${theme.nodeText},stroke-width:2px"
            "  classDef matrixhost_c fill:${theme.rootFill},stroke:${theme.rootStroke},color:${theme.rootText},font-weight:bold"
            "  style providers fill:${theme.clusterBg},stroke:${theme.clusterBorder},stroke-width:2px"
            "  style hostsCluster fill:${theme.clusterBg},stroke:${theme.clusterBorder},stroke-width:2px"
          ]
        );

  toTreemapMermaid = toTreemapMermaidWith { };
  toFleetTreemapMermaid = toFleetTreemapMermaidWith { };
  toFleetProviderMatrix = toFleetProviderMatrixWith { };
in
{
  inherit
    toTreemapMermaid
    toTreemapMermaidWith
    toFleetTreemapMermaid
    toFleetTreemapMermaidWith
    toFleetProviderMatrix
    toFleetProviderMatrixWith
    ;
}
