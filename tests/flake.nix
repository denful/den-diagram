{
  description = "den-gram tests";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    den-gram.url = "path:..";
  };

  outputs =
    { nixpkgs, den-gram, ... }:
    let
      lib = nixpkgs.lib;
      gram = den-gram.lib;
    in
    {
      tests = import ./tests.nix { inherit lib gram; };
    };
}
