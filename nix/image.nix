# SPDX-License-Identifier: MIT
{ pkgs }:
let
  sourceIso = pkgs.fetchurl {
    url = "https://downloads.sourceforge.net/project/android-x86/Release%209.0/android-x86_64-9.0-r2.iso";
    hash = "sha256-9+uPxW8prVQyM13AVBg6zwhsU585kPC26f9YvW30YE4=";
  };
  image =
    pkgs.runCommand "android-x86-9-test-image"
      {
        nativeBuildInputs = [
          pkgs.libarchive
          pkgs.squashfsTools
          pkgs.e2fsprogs
          pkgs.zerofree
          pkgs.xorriso
        ];
        passthru = {
          inherit sourceIso;
          iso = "${image}/boot.iso";
        };
      }
      ''
        mkdir -p "$out"
        bsdtar -xf ${sourceIso} kernel initrd.img system.sfs
        cp kernel initrd.img "$out/"
        unsquashfs -no-progress -d system system.sfs
        debugfs -R "dump -p /framework/framework-res.apk $out/framework-res.apk" system/system.img
        test -s "$out/framework-res.apk"
        # These unrelated preinstalled apps dominate first-boot compilation and
        # starve Android's UI watchdog under software QEMU on small CI runners.
        export E2FSPROGS_FAKE_TIME=1
        for apk in /app/Chrome/Chrome.apk /priv-app/GmsCore/GmsCore.apk; do
          debugfs -R "stat $apk" system/system.img > before.log 2>&1
          grep '^Inode:' before.log
          debugfs -w -R "rm $apk" system/system.img
          debugfs -R "stat $apk" system/system.img > after.log 2>&1
          if grep '^Inode:' after.log; then echo "fixture APK removal failed: $apk" >&2; exit 1; fi
        done
        zerofree system/system.img
        env -u SOURCE_DATE_EPOCH mksquashfs system system.cleaned.sfs -noappend -all-root -all-time 1 -mkfs-time 1 -no-progress -processors 1
        xorriso -indev ${sourceIso} -outdev "$out/boot.iso" -map system.cleaned.sfs /system.sfs -boot_image any replay
      '';
in
image
