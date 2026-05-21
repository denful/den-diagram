{
  description = "Diagram library for den — graph IR, renderers, and fleet views";

  inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";

  outputs =
    { nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
    in
    {
      lib = import ./nix { inherit lib; };
    };
}
