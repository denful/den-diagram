{
  description = "den-diagram tests";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    den-diagram.url = "path:..";
  };

  outputs =
    { nixpkgs, den-diagram, ... }:
    let
      inherit (nixpkgs) lib;
      diagram = den-diagram.lib;
    in
    {
      tests = import ./tests.nix { inherit lib diagram; };
    };
}
