# Theme records for the diag renderer library.
#
# A theme record bundles every color the renderers need: backgrounds,
# foregrounds, cluster/subgraph surfaces, edge colors, adapter styling,
# and an accent pool used by the per-node color hash. Every renderer
# (mermaid, dot, plantuml, c4) consumes the same record so swapping a
# theme updates all diagram types consistently.
#
# Themes are built from base16 palettes. `pkgs.base16-schemes` ships
# ~300 schemes as YAML; we convert a requested scheme to JSON via `yj`
# at build time and parse it with `builtins.fromJSON`.
#
# Usage from a template:
#
#   theme = diag.themeFromBase16 { inherit pkgs; scheme = "catppuccin-mocha"; };
#   rendered = diag.toMermaid { inherit theme; } graph;
{ lib }:
let
  # Convert a base16 YAML scheme file into a parsed palette via `yj`.
  # Returns the attribute set `{ base00 = "#..."; ... base0F = "#..."; }`.
  paletteFromBase16 =
    { pkgs, scheme }:
    let
      yamlFile = "${pkgs.base16-schemes}/share/themes/${scheme}.yaml";
      jsonDrv =
        pkgs.runCommand "base16-${scheme}.json"
          {
            nativeBuildInputs = [ pkgs.yj ];
          }
          ''
            yj < ${yamlFile} > $out
          '';
      parsed = builtins.fromJSON (builtins.readFile jsonDrv);
      # base16 YAML values usually include the leading "#" but some
      # schemes historically omit it; normalize so downstream code can
      # concatenate without thinking.
      normalize = v: if lib.hasPrefix "#" v then v else "#${v}";
    in
    lib.mapAttrs (_: normalize) parsed.palette;

  # Map a base16 palette onto our theme record. base16's semantic slots
  # align reasonably with our needs:
  #
  #   base00 = default background       → background
  #   base01 = lighter background       → clusterBg / nodeBg
  #   base03 = comments / faded         → subtle edges
  #   base04 = dark foreground          → nodeBorder / clusterBorder
  #   base05 = default foreground       → foreground / nodeText
  #   base08 = red                      → excluded nodes
  #   base09 = orange                   → replaced nodes
  #   base0A..base0F                    → accent pool for per-node hashing
  #
  # `accentPool` is the list of 8 hues the per-node color hash selects
  # from. Keeping to base16's accent slots means every diagram's nodes
  # stay faithful to the chosen scheme.
  # Detect whether a palette is "light" (light base00 background) by
  # comparing the first hex digit of base00 vs base05. In base16:
  #   - Dark schemes: base00 is dark (low hex), base05 is light (high hex)
  #   - Light schemes: base00 is light (high hex), base05 is dark (low hex)
  isLightPalette =
    palette:
    let
      bg = builtins.substring 1 1 palette.base00; # first hex digit after #
      fg = builtins.substring 1 1 palette.base05;
    in
    (hexToInt bg) > (hexToInt fg);

  # Hex digit lookup (reused from colors.nix pattern)
  hexToInt =
    c:
    {
      "0" = 0;
      "1" = 1;
      "2" = 2;
      "3" = 3;
      "4" = 4;
      "5" = 5;
      "6" = 6;
      "7" = 7;
      "8" = 8;
      "9" = 9;
      "a" = 10;
      "b" = 11;
      "c" = 12;
      "d" = 13;
      "e" = 14;
      "f" = 15;
      "A" = 10;
      "B" = 11;
      "C" = 12;
      "D" = 13;
      "E" = 14;
      "F" = 15;
    }
    .${c} or 0;

  themeFromPalette =
    palette:
    let
      light = isLightPalette palette;
      # Text on accent fills: need maximum contrast against vivid mid-tones.
      # Dark themes: base00 (dark background) on bright fills.
      # Light themes: base07 (dark foreground end) on bright fills.
      contrastText = if light then palette.base07 else palette.base00;
    in
    {
      inherit palette;
      background = palette.base00;
      foreground = palette.base05;
      mutedForeground = palette.base04;
      nodeBg = palette.base01;
      nodeBorder = palette.base04;
      nodeText = palette.base05;
      clusterBg = palette.base01;
      clusterBorder = palette.base03;
      edgeColor = palette.base04;
      edgeText = palette.base05;
      labelBg = palette.base00;
      rootFill = palette.base0D;
      rootStroke = palette.base0D;
      rootText = contrastText;
      excludedFill = palette.base08;
      excludedStroke = palette.base08;
      excludedText = contrastText;
      replacedFill = palette.base09;
      replacedStroke = palette.base09;
      replacedText = contrastText;
      accentPool = [
        palette.base08
        palette.base09
        palette.base0A
        palette.base0B
        palette.base0C
        palette.base0D
        palette.base0E
        palette.base0F
      ];
    };

  # One-shot helper: scheme name → theme record.
  themeFromBase16 =
    { pkgs, scheme }:
    themeFromPalette (paletteFromBase16 {
      inherit pkgs scheme;
    });

  # Build a mermaid `%%{init: {...}}%%` preamble from a theme record
  # and optional extra config. We use the init directive (rather than
  # YAML frontmatter) because mermaid's frontmatter `config:` parser
  # silently drops several keys we care about — most notably `themeCSS`,
  # which we need to override the canvas background. The init directive
  # accepts the full mermaidAPI config including themeCSS, layout,
  # themeVariables, flowchart options, and so on.
  #
  # `extraConfig` is recursively merged *over* our theme-derived base
  # config, so callers can set `layout = "elk"`, tweak `flowchart.curve`,
  # override individual themeVariables, etc., without losing the theme.
  mermaidFrontmatter =
    theme: extraConfig:
    let
      t = theme;
      vars = {
        # Shared / flowchart
        inherit (t) background;
        mainBkg = t.nodeBg;
        secondBkg = t.clusterBg;
        tertiaryColor = t.clusterBg;
        primaryColor = t.nodeBg;
        primaryTextColor = t.nodeText;
        primaryBorderColor = t.nodeBorder;
        secondaryColor = t.clusterBg;
        secondaryTextColor = t.foreground;
        secondaryBorderColor = t.clusterBorder;
        tertiaryTextColor = t.foreground;
        tertiaryBorderColor = t.clusterBorder;
        lineColor = t.edgeColor;
        textColor = t.foreground;
        nodeBkg = t.nodeBg;
        nodeTextColor = t.nodeText;
        inherit (t) nodeBorder;
        clusterBkg = t.clusterBg;
        inherit (t) clusterBorder;
        edgeLabelBackground = t.labelBg;
        titleColor = t.foreground;
        # Sequence diagrams
        actorBkg = t.nodeBg;
        actorBorder = t.nodeBorder;
        actorTextColor = t.nodeText;
        actorLineColor = t.edgeColor;
        signalColor = t.edgeColor;
        signalTextColor = t.edgeText;
        labelBoxBkgColor = t.nodeBg;
        labelBoxBorderColor = t.nodeBorder;
        labelTextColor = t.nodeText;
        loopTextColor = t.foreground;
        noteBkgColor = t.clusterBg;
        noteBorderColor = t.clusterBorder;
        noteTextColor = t.foreground;
        activationBkgColor = t.clusterBg;
        activationBorderColor = t.clusterBorder;
        sequenceNumberColor = t.background;
        # Class / state / ER
        classText = t.foreground;
        # Pie / sankey / treemap accent colors
        pie1 = builtins.elemAt t.accentPool 0;
        pie2 = builtins.elemAt t.accentPool 1;
        pie3 = builtins.elemAt t.accentPool 2;
        pie4 = builtins.elemAt t.accentPool 3;
        pie5 = builtins.elemAt t.accentPool 4;
        pie6 = builtins.elemAt t.accentPool 5;
        pie7 = builtins.elemAt t.accentPool 6;
        pie8 = builtins.elemAt t.accentPool 7;
        pieTitleTextColor = t.foreground;
        pieSectionTextColor = t.foreground;
        pieLegendTextColor = t.foreground;
        pieStrokeColor = t.clusterBorder;
        pieOuterStrokeColor = t.clusterBorder;
      };
      baseConfig = {
        theme = "base";
        themeVariables = vars;
      };
      merged = lib.recursiveUpdate baseConfig extraConfig;
    in
    "%%{init: ${builtins.toJSON merged}}%%";

  # Sensible default theme that doesn't require pkgs — hard-coded github
  # light palette so the library is usable without running yj. Renderers
  # fall back to this when their caller doesn't thread a theme through.
  defaultPalette = {
    base00 = "#eaeef2";
    base01 = "#d0d7de";
    base02 = "#afb8c1";
    base03 = "#8c959f";
    base04 = "#6e7781";
    base05 = "#424a53";
    base06 = "#32383f";
    base07 = "#1f2328";
    base08 = "#fa4549";
    base09 = "#e16f24";
    base0A = "#bf8700";
    base0B = "#2da44e";
    base0C = "#339D9B";
    base0D = "#218bff";
    base0E = "#a475f9";
    base0F = "#4d2d00";
  };
  defaultTheme = themeFromPalette defaultPalette;
in
{
  inherit
    paletteFromBase16
    themeFromPalette
    themeFromBase16
    defaultTheme
    mermaidFrontmatter
    ;
}
