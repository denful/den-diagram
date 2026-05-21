{ inputs, lib, ... }:
let
  diagram = import "${inputs.target}/nix" { inherit lib; };
  allTests = import "${inputs.target}/tests/tests.nix" { inherit lib diagram; };
in
{
  flake.tests = allTests;
}
