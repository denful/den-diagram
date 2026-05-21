# Nix derivation builders for SVG conversion.
#
# Provides mmdSourceToSvg, pumlSourceToSvg, dotSourceToSvg — pkgs-heavy
# build infrastructure orthogonal to graph IR.
{ lib }:
{
  pkgs,
  theme,
  renderFonts ? [
    pkgs.jetbrains-mono
    pkgs.fira-code
    pkgs.dejavu_fonts
    pkgs.liberation_ttf
    pkgs.noto-fonts
  ],
  fontFamily ? "JetBrains Mono, Fira Code, DejaVu Sans Mono, monospace",
  mermaidCli ? pkgs.mermaid-cli,
}:
let
  renderFontsConf = pkgs.makeFontsConf { fontDirectories = renderFonts; };
  renderFontEnv = ''
    export HOME=$TMPDIR
    export XDG_CACHE_HOME=$TMPDIR/.cache
    export XDG_CONFIG_HOME=$TMPDIR/.config
    mkdir -p "$XDG_CACHE_HOME/fontconfig" "$XDG_CONFIG_HOME/fontconfig"
  '';

  mmdPuppeteerConfig = pkgs.writeText "puppeteer-config.json" (
    builtins.toJSON {
      args = [
        "--no-sandbox"
        "--disable-dev-shm-usage"
      ];
    }
  );
  mmdConfig = pkgs.writeText "mermaid-config.json" (
    builtins.toJSON {
      maxTextSize = 10000000;
      maxEdges = 100000;
      inherit fontFamily;
      securityLevel = "loose";
    }
  );

  mmdSourceToSvg =
    baseName: source:
    let
      src = pkgs.writeText "${baseName}.mmd" source;
    in
    pkgs.runCommand "${baseName}.mmd.svg"
      {
        buildInputs = renderFonts;
        FONTCONFIG_FILE = renderFontsConf;
      }
      ''
        ${renderFontEnv}
        if ${mermaidCli}/bin/mmdc \
              -i ${src} \
              -o "$TMPDIR/out.svg" \
              -p ${mmdPuppeteerConfig} \
              -c ${mmdConfig} \
              -b '${theme.background}' \
              -q 2>"$TMPDIR/mmd-err"; then
          cp "$TMPDIR/out.svg" "$out"
        else
          echo "mermaid-cli failed for ${baseName}:" >&2
          cat "$TMPDIR/mmd-err" >&2 || true
          cat > $out <<'PLACEHOLDER_EOF'
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="720" height="100" viewBox="0 0 720 100">
          <rect width="720" height="100" fill="#fff8e1" stroke="#b08930" stroke-width="2"/>
          <text x="20" y="40" font-family="sans-serif" font-size="14" font-weight="bold" fill="#b05060">
            Mermaid render unavailable
          </text>
          <text x="20" y="64" font-family="sans-serif" font-size="12" fill="#5a5a5a">
            This diagram type may require a newer mermaid than available.
          </text>
          <text x="20" y="82" font-family="monospace" font-size="11" fill="#666">
            See source in the accompanying .md file.
          </text>
        </svg>
        PLACEHOLDER_EOF
        fi
      '';

  pumlSourceToSvg =
    baseName: source:
    let
      src = pkgs.writeText "${baseName}.puml" source;
    in
    pkgs.runCommand "${baseName}.puml.svg"
      {
        buildInputs = renderFonts;
        FONTCONFIG_FILE = renderFontsConf;
      }
      ''
        ${renderFontEnv}
        ${pkgs.plantuml}/bin/plantuml -tsvg -pipe < ${src} > $out
      '';

  dotSourceToSvg =
    base: source:
    let
      src = pkgs.writeText "${base}.dot" source;
    in
    pkgs.runCommand "${base}.dot.svg"
      {
        buildInputs = renderFonts;
        FONTCONFIG_FILE = renderFontsConf;
      }
      ''
        ${renderFontEnv}
        ${pkgs.graphviz}/bin/dot -Tsvg -o $out ${src}
      '';
in
{
  inherit
    renderFonts
    renderFontsConf
    mmdSourceToSvg
    pumlSourceToSvg
    dotSourceToSvg
    ;
}
