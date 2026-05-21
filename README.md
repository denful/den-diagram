# den-diagram

Diagram library for [den](https://github.com/denful/den) — graph IR construction, filtering, and multi-format rendering of aspect-resolution pipelines.

## Usage

Add as a flake input:

```nix
inputs.den-diagram.url = "github:denful/den-diagram";
```

### Two-step pattern: capture in den, render in den-diagram

Den's capture layer runs the fx pipeline with tracing handlers and produces structured trace entries. Den-diagram turns those entries into graphs and rendered diagrams.

```nix
gram = inputs.den-diagram.lib;

# 1. Capture — runs in den, produces trace data
captured = den.lib.capture.captureWithPathsWith {
  classes = [ "nixos" "homeManager" ];
  root = den.lib.resolveEntity "host" { inherit host; };
  ctx = { inherit host; };
};

# 2. Context — builds format-agnostic graph IR from trace entries
g = gram.context {
  entries = captured.entries;
  ctxTrace = captured.ctxTrace;
  name = host.name;
};

# 3. Render — emit diagram source in any supported format
rendered = gram.toMermaid g;
```

### Fleet graphs

```nix
fleetData = gram.fleet.of {
  hosts = den.hosts;
  flakeName = "my-fleet";
};
gram.toC4Context fleetData;
```

### Namespace graph (static aspect declarations)

```nix
g = gram.graph.ofNamespace { aspects = den.aspects; };
gram.toMermaid g;
```

### Render context (SVG pipeline with mermaid-cli)

```nix
rc = gram.renderContext {
  inherit pkgs;
  theme = gram.themeFromBase16 { inherit pkgs; scheme = "catppuccin-mocha"; };
};
svg = rc.mmdSourceToSvg "my-diagram" (gram.toMermaid g);
```

## Renderers

| Function | Format |
|----------|--------|
| `toMermaid` | Mermaid flowchart |
| `toDot` | Graphviz DOT |
| `toPlantUML` | PlantUML |
| `toC4Component`, `toC4Container`, `toC4Context` | PlantUML C4 |
| `toC4ComponentMermaid`, `toC4ContainerMermaid`, `toC4ContextMermaid` | Mermaid C4 |
| `toSequenceMermaid` | Scope sequence |
| `toPolicySequenceMermaid` | Policy sequence |
| `toSankeyMermaid`, `toFleetSankeyMermaid` | Sankey |
| `toTreemapMermaid`, `toFleetTreemapMermaid` | Treemap |
| `toMindmapMermaid` | Mindmap |
| `toStateMermaid` | State diagram |
| `toPipeFlowMermaid` | Pipe data flow |
| `toScopeTopologyMermaid` | Scope topology |
| `toFleetDagMermaid` | Fleet DAG |
| `toJSON` | Graph IR JSON |

Each renderer has a `*With` variant accepting `{ theme, mermaidConfig }` for customization.

## Graph filters

```nix
gram.graph.aspectsOnly g;         # aspect hierarchy only
gram.graph.providersOnly g;       # provider tree
gram.graph.contextOnly g;         # context scopes
gram.graph.simplified g;          # fold providers
gram.graph.classSlice "nixos" g;  # single class
gram.graph.diffClasses g;         # class comparison
gram.graph.filterUserAspects g;   # user-declared only
```

## Architecture

Den-diagram is a pure Nix library — it depends only on `nixpkgs.lib`. It has no dependency on den's fx pipeline or module system. The library accepts pre-captured trace data as plain attrsets, making the dependency one-directional: den → den-diagram.

```
den (capture.nix)          den-diagram
┌─────────────────┐        ┌──────────────────────┐
│ captureWithPaths │──data─▶│ context → graph IR   │
│ captureFleet     │        │ filters → pruned IR  │
│ captureAll       │        │ renderers → strings  │
└─────────────────┘        │ export → derivations  │
                           └──────────────────────┘
```
