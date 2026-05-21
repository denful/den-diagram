# State diagram renderer (mermaid `stateDiagram-v2`).
#
# The context resolution pipeline is semantically a state machine:
# `host` is the initial state, `default` / `hm-host` / `hm-user` / `user`
# are intermediate states, transitions are cross-stage provides.
# stateDiagram-v2 models this more accurately than a flowchart.
#
# Intended for `diag.graph.contextOnly` output — a graph whose nodes
# are stage-synthesized and edges are stage transitions. Falls back
# to rendering every node as a state if given a different shape.
{
  lib,
  themes,
  util,
  renderUtil,
}:
let
  inherit (util) sanitizeChars;
  inherit (renderUtil) renderMermaid;

  toStateMermaidWith =
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

      # stateDiagram state ids must be alnum/underscore; use sanitizeChars
      # without any prefix since we control the names here.
      stateId = node: "s_${sanitizeChars node.label}";

      nonHostNodes = builtins.filter (n: n.id != rootId) nodes;
      nodeById = builtins.listToAttrs (
        map (n: {
          name = n.id;
          value = n;
        }) nodes
      );

      stateDecl = node: "    ${stateId node} : ${node.label}";

      edgeLine =
        edge:
        let
          fromNode = nodeById.${edge.from} or null;
          toNode = nodeById.${edge.to} or null;
          fromState =
            if fromNode == null then
              edge.from
            else if fromNode.id == rootId then
              "[*]"
            else
              stateId fromNode;
          toState =
            if toNode == null then
              edge.to
            else if toNode.id == rootId then
              "[*]"
            else
              stateId toNode;
          label = if edge.label != null then " : ${edge.label}" else "";
        in
        "    ${fromState} --> ${toState}${label}";

      # Drop self-loops (from == to after host-replacement) to match the
      # filter we already apply to the sequence view.
      isSelf = edge: edge.from == edge.to;
      keptEdges = builtins.filter (e: !(isSelf e)) edges;
    in
    if nonHostNodes == [ ] then
      renderMermaid
        {
          inherit theme mermaidConfig;
          diagramKind = "stateDiagram-v2";
        }
        [
          "    [*] --> ${sanitizeChars rootName}"
          "    ${sanitizeChars rootName} : ${rootName}"
          "    ${sanitizeChars rootName} --> [*]"
        ]
    else
      renderMermaid {
        inherit theme mermaidConfig;
        diagramKind = "stateDiagram-v2";
      } (map stateDecl nonHostNodes ++ [ "" ] ++ map edgeLine keptEdges);

  toStateMermaid = toStateMermaidWith { };
in
{
  inherit toStateMermaid toStateMermaidWith;
}
