# hasAspect presence filters.
{
  lib,
  util,
  filterByNodes,
  filterUserAspects,
  ...
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
        graph.pathsByClass
          or (throw "hasAspectPresent: graph has no pathsByClass; build it with diagram.context, passing the pathsByClass of den.lib.capture.captureWithPaths.");
      pathSet =
        pathSets.${class}
          or (throw "hasAspectPresent: no pathSet captured for class '${class}'. Known classes: ${lib.concatStringsSep ", " (builtins.attrNames pathSets)}. projectScope graphs carry none; use diagram.context.");
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
