{ inputs, lib, ... }:
let
  gram = import "${inputs.target}/nix" { inherit lib; };
  allTests = import "${inputs.target}/tests/tests.nix" { inherit lib gram; };
in
{
  flake.tests = allTests;
}
