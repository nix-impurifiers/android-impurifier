# SPDX-License-Identifier: MIT
{ pkgs }:
let
  image = import ../nix/image.nix { inherit pkgs; };
in
pkgs.runCommand "android-native-framework-probe"
  {
    nativeBuildInputs = [
      pkgs.qemu
      pkgs.android-tools
      pkgs.python3
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    python3 ${./probe.py} ${image} ${image.iso}
    touch "$out"
  ''
