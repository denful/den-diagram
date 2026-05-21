# Render context factory.
#
# Builds a record carrying everything needed to render views:
# pre-configured renderer sets and SVG builder functions.
{
  themes,
  renderers,
  renderInfra,
  views,
}:
{
  pkgs,
  theme ? themes.defaultTheme,
  mermaidConfig ? { },
  mermaidCli ? pkgs.mermaid-cli,
  renderFonts ? [
    pkgs.jetbrains-mono
    pkgs.fira-code
    pkgs.dejavu_fonts
    pkgs.liberation_ttf
    pkgs.noto-fonts
  ],
  fontFamily ? "JetBrains Mono, Fira Code, DejaVu Sans Mono, monospace",
}:
let
  infra = renderInfra {
    inherit
      pkgs
      theme
      renderFonts
      fontFamily
      mermaidCli
      ;
  };
  render = renderers { inherit theme; };
  renderDense = renderers { inherit theme mermaidConfig; };
  # Self-referential: rc passes itself to view constructors so views
  # can access render/renderDense/mmdSourceToSvg from the same record.
  # Works because Nix attrsets are lazily evaluated.
  rc = infra // {
    inherit render renderDense theme;
    views = {
      core = views.core rc;
      host = views.host rc;
      user = views.user rc;
      home = views.home rc;
      fleet = views.fleet rc;
      classViews = views.classViews rc;
    };
  };
in
rc
