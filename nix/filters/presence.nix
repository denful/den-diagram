# hasAspect presence filters.
{
  lib,
  util,
  graphLib,
  filterByNodes,
  filterUserAspects,
}:
let
  inherit (util)
    isTombstone
    ancestorClosureBy
    ;

  # hasAspect presence slice: nodes that would answer
  # `entity.hasAspect <ref>` = true for a given class.
  # Ancestor closure keeps the organizer chain visible.
  hasAspectPresentWith =
    pathSet: graph:
    let
      filtered = filterUserAspects graph;
      isPresent = n: pathSet ? ${n.pathKey} || isTombstone n;
    in
    ancestorClosureBy isPresent filtered;

  hasAspectPresent =
    { class }:
    graph:
    let
      pathSets =
        graph.pathSets
          or (throw "hasAspectPresent: graph is missing pathSets; build via diag.graph.hostContext, not ofHost.");
      pathSet =
        pathSets.${class}
          or (throw "hasAspectPresent: no pathSet captured for class '${class}'. Known classes: ${lib.concatStringsSep ", " (builtins.attrNames pathSets)}.");
    in
    hasAspectPresentWith pathSet graph;

  # Union of hasAspectPresent across multiple classes: a node is kept
  # if it appears in the presence set of ANY class.
  hasAspectForAnyClass =
    classes: graph:
    let
      perClass = builtins.map (c: hasAspectPresent { class = c; } graph) classes;
      keepIds = lib.foldl' (
        acc: g: lib.foldl' (acc': n: acc' // { ${n.id} = true; }) acc g.nodes
      ) { } perClass;
    in
    filterByNodes (n: keepIds ? ${n.id}) graph;
in
{
  inherit hasAspectPresentWith hasAspectPresent hasAspectForAnyClass;
}
