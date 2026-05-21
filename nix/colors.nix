# Per-node color selection from a theme's accent pool.
#
# Hashes a node's name and category into one of the theme's accent slots
# (base08-base0F in base16 terms). Nodes with the same category cluster
# around a small range of indices, while each individual name still gets
# a stable-but-distinct selection. The result is scheme-faithful: every
# node color is drawn from the user's chosen base16 palette.
{ lib }:
let
  # Hex-digit → integer lookup.
  hexDigits = {
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
  };
  hexToInt = c: hexDigits.${c} or 0;

  # Parse a 4-character hex substring into an integer. Used to turn the
  # first 16 bits of an md5 hash into a number we can modulo against
  # the accent pool size.
  parseHex4 =
    s:
    (hexToInt (builtins.substring 0 1 s)) * 4096
    + (hexToInt (builtins.substring 1 1 s)) * 256
    + (hexToInt (builtins.substring 2 1 s)) * 16
    + (hexToInt (builtins.substring 3 1 s));

  hashNum = s: parseHex4 (builtins.substring 0 4 (builtins.hashString "md5" s));

  # Given a theme and a (category, name) pair, pick an accent color from
  # the theme's palette. The category biases the starting offset so
  # related nodes sit near each other in the pool; the name adds a small
  # per-item perturbation so they don't all land on the same color.
  #
  # `* 7` on the category hash is deliberate — 7 is coprime with the
  # 8-slot accent pool, so distinct category names land on maximally
  # distinct starting offsets instead of bunching on a few buckets.
  nodeColorFor =
    theme: category: name:
    let
      pool = theme.accentPool;
      poolSize = builtins.length pool;
      cat = if category != null then category else "default";
      categoryBase = lib.mod ((hashNum cat) * 7) poolSize;
      nameOffset = lib.mod (hashNum name) 3; # 0, 1, or 2
      index = lib.mod (categoryBase + nameOffset) poolSize;
    in
    builtins.elemAt pool index;

  # Back-compat shim: `nodeColor category name` without a theme argument
  # falls back to a built-in github-light palette. Renderers that accept
  # a theme should pass it through `nodeColorFor` explicitly.
  defaultPool = [
    "#fa4549" # red
    "#e16f24" # orange
    "#bf8700" # yellow
    "#2da44e" # green
    "#339D9B" # teal
    "#218bff" # blue
    "#a475f9" # purple
    "#4d2d00" # brown
  ];
  nodeColor = category: name: nodeColorFor { accentPool = defaultPool; } category name;
in
{
  inherit nodeColor nodeColorFor;
}
