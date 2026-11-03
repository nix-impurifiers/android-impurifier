# SPDX-License-Identifier: MIT
{ ... }:
{ lib, ... }:
{
  flake.lib = lib.mkForce {
    android-impurifier = { pkgs }: import ../../../nix { inherit pkgs; };
  };
  perSystem =
    { pkgs, ... }:
    let
      backend = import ../../../nix { inherit pkgs; };
    in
    {
      packages.default = backend.package;
      packages.native-client = backend.nativeClient;
      packages.example-unsigned = import ../../../tests/application.nix { inherit pkgs backend; };
      checks.archive = import ../../../tests/archive.nix { inherit pkgs backend; };
      checks.native-vm = import ../../../tests/lifecycle.nix { inherit pkgs backend; };
      formatter = pkgs.nixfmt-tree;
    };
}
