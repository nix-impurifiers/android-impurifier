# SPDX-License-Identifier: MIT
{ pkgs }:
let
  iso = pkgs.fetchurl {
    url = "https://downloads.sourceforge.net/project/android-x86/Release%209.0/android-x86_64-9.0-r2.iso";
    hash = "sha256-9+uPxW8prVQyM13AVBg6zwhsU585kPC26f9YvW30YE4=";
  };
in
pkgs.runCommand "android-x86-9-test-image"
  {
    nativeBuildInputs = [
      pkgs.libarchive
      pkgs.squashfsTools
      pkgs.e2fsprogs
    ];
    passthru = { inherit iso; };
  }
  ''
    mkdir -p "$out"
    bsdtar -xf ${iso} kernel initrd.img system.sfs
    cp kernel initrd.img "$out/"
    unsquashfs -no-progress -d system system.sfs
    debugfs -R "dump -p /framework/framework-res.apk $out/framework-res.apk" system/system.img
    test -s "$out/framework-res.apk"
  ''
