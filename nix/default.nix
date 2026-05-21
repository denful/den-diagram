# den-gram — standalone diagram library.
#
# Pure graph IR, renderers, and fleet views extracted from den.
# No den, capture, or inputs dependencies.
{ lib }:
let
  util = import ./util.nix { inherit lib; };
  colors = import ./colors.nix { inherit lib; };
  themes = import ./themes.nix { inherit lib; };
  renderUtil = import ./render-util.nix { inherit lib themes; };
  graphLib = import ./graph.nix { inherit lib util; };
  filtersLib = import ./filters { inherit lib util graphLib; };
  mermaid = import ./mermaid.nix {
    inherit
      lib
      themes
      colors
      util
      renderUtil
      ;
  };
  dot = import ./dot.nix {
    inherit
      lib
      themes
      colors
      util
      renderUtil
      ;
  };
  plantuml = import ./plantuml.nix {
    inherit
      lib
      themes
      colors
      util
      renderUtil
      ;
  };
  sequence = import ./sequence.nix {
    inherit
      lib
      themes
      util
      renderUtil
      ;
  };
  c4 = import ./c4.nix {
    inherit
      lib
      themes
      util
      renderUtil
      ;
  };
  sankey = import ./sankey.nix {
    inherit
      lib
      themes
      util
      renderUtil
      ;
  };
  treemap = import ./treemap.nix {
    inherit
      lib
      themes
      util
      renderUtil
      ;
  };
  mindmap = import ./mindmap.nix {
    inherit
      lib
      themes
      util
      renderUtil
      ;
  };
  state = import ./state.nix {
    inherit
      lib
      themes
      util
      renderUtil
      ;
  };
  pipeFlow = import ./fleet-views.nix {
    inherit
      lib
      themes
      util
      renderUtil
      ;
  };
  textLib = import ./text.nix { inherit lib; };
  fleetIR = import ./fleet-ir.nix { inherit lib; };
  fleetLib = import ./fleet.nix { inherit lib; };
  exportLib = import ./export.nix { inherit lib; };
  json = import ./json.nix { inherit lib graphLib; };

  ctxLib = import ./context.nix { inherit lib graphLib; };
  namespaceGraph = import ./namespace.nix { inherit lib util graphLib; };
  renderInfraFn = import ./render-infra.nix { inherit lib; };

  inherit (ctxLib) context;

  graph = {
    build = graphLib.buildGraph;
    ofNamespace = namespaceGraph;
  } // filtersLib;

  fleet = {
    of = fleetLib.fleetGraph;
    inherit (fleetLib) flattenHosts;
  };

  pipes = {
    buildFlows = pipeFlow.buildPipeFlows;
  };

  fleetGraph = {
    build = fleetIR.buildFleetIR;
    toJSON = fleetIR.toFleetJSON;
  };

  text = textLib;

  inherit (json) toJSON;

  views = import ./views.nix { inherit graph toJSON; };

  inherit (renderUtil) mkRenderer;

  rendererSpecs = {
    toMermaid = {
      withFn = mermaid.toMermaidWith;
      mc = true;
    };
    toDot = {
      withFn = dot.toDotWith;
      mc = false;
    };
    toPlantUML = {
      withFn = plantuml.toPlantUMLWith;
      mc = false;
    };
    toSequenceMermaid = {
      withFn = sequence.toSequenceMermaidWith;
      mc = true;
    };
    toSequenceMermaidExpanded = {
      withFn = sequence.toSequenceMermaidExpandedWith;
      mc = true;
    };
    toPolicySequenceMermaid = {
      withFn = sequence.toPolicySequenceMermaidWith;
      mc = true;
    };
    toScopeEdgesMermaid = {
      withFn = sequence.toScopeEdgesMermaidWith;
      mc = true;
    };
    toSankeyMermaid = {
      withFn = sankey.toSankeyMermaidWith;
      mc = true;
    };
    toFleetSankeyMermaid = {
      withFn = sankey.toFleetSankeyMermaidWith;
      mc = true;
    };
    toFanMetricsSankey = {
      withFn = sankey.toFanMetricsSankeyWith;
      mc = true;
    };
    toTreemapMermaid = {
      withFn = treemap.toTreemapMermaidWith;
      mc = true;
    };
    toFleetTreemapMermaid = {
      withFn = treemap.toFleetTreemapMermaidWith;
      mc = true;
    };
    toFleetProviderMatrix = {
      withFn = treemap.toFleetProviderMatrixWith;
      mc = true;
    };
    toC4Component = {
      withFn = c4.toC4ComponentWith;
      mc = false;
    };
    toC4Container = {
      withFn = c4.toC4ContainerWith;
      mc = false;
    };
    toC4Context = {
      withFn = c4.toC4ContextWith;
      mc = false;
    };
    toC4ComponentMermaid = {
      withFn = c4.toC4ComponentMermaidWith;
      mc = true;
    };
    toC4ContainerMermaid = {
      withFn = c4.toC4ContainerMermaidWith;
      mc = true;
    };
    toC4ContextMermaid = {
      withFn = c4.toC4ContextMermaidWith;
      mc = true;
    };
    toMindmapMermaid = {
      withFn = mindmap.toMindmapMermaidWith;
      mc = true;
    };
    toStateMermaid = {
      withFn = state.toStateMermaidWith;
      mc = true;
    };
    toPipeFlowMermaid = {
      withFn = pipeFlow.toPipeFlowMermaidWith;
      mc = true;
    };
    toScopeTopologyMermaid = {
      withFn = pipeFlow.toScopeTopologyMermaidWith;
      mc = true;
    };
    toAspectMatrixMermaid = {
      withFn = pipeFlow.toAspectMatrixMermaidWith;
      mc = true;
    };
    toPolicyResolutionMapMermaid = {
      withFn = pipeFlow.toPolicyResolutionMapMermaidWith;
      mc = true;
    };
    toPipeSequenceMermaid = {
      withFn = pipeFlow.toPipeSequenceMermaidWith;
      mc = true;
    };
    toFleetDagMermaid = {
      withFn = pipeFlow.toFleetDagMermaidWith;
      mc = true;
    };
  };

  allRenderers = builtins.foldl' (
    acc: name: acc // mkRenderer name rendererSpecs.${name}.withFn
  ) { } (builtins.attrNames rendererSpecs);

  renderers =
    {
      theme ? themes.defaultTheme,
      mermaidConfig ? { },
    }:
    builtins.foldl' (
      acc: name:
      let
        spec = rendererSpecs.${name};
        args = {
          inherit theme;
        } // lib.optionalAttrs spec.mc { inherit mermaidConfig; };
      in
      acc // { ${name} = spec.withFn args; }
    ) { toJSON = toJSON; } (builtins.attrNames rendererSpecs);

  renderInfra = renderInfraFn;

  renderContext = import ./render-context.nix {
    inherit
      themes
      renderers
      renderInfra
      views
      ;
  };

in
{
  inherit
    context
    graph
    fleet
    fleetGraph
    pipes
    text
    views
    renderers
    renderContext
    renderInfra
    toJSON
    ;
  export = exportLib;

  inherit (colors) nodeColor nodeColorFor;
  inherit (themes)
    paletteFromBase16
    themeFromPalette
    themeFromBase16
    defaultTheme
    ;
} // allRenderers
