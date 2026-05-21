# Entity-agnostic context constructor.
#
# Accepts pre-captured data (entries, ctxTrace, pathsByClass) and builds
# graph IR. The caller is responsible for resolving entities and capturing
# trace data — this module has no den or capture dependency.
{ graphLib, ... }:
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
}
