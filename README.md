# android-impurifier

Build native Android application APKs from Nix-built Android inputs. This is a
separate ecosystem from Termux packages. No Nix executable, daemon, store database,
NixOS userspace or glibc is required on the device.

```nix
let android = android-impurifier.lib.android-impurifier { inherit pkgs; };
in android.makeApplication {
  name = "my-app";
  manifest = ./AndroidManifest.xml;
  framework = "${androidPlatform}/android.jar";
  dexFiles = [ myDex ];
  nativeLibraries.arm64-v8a."libapp.so" = myAndroidLibrary;
  assets = ./assets;
  resources = ./res;
}
```

Supply `manifest` and `framework`, or a prelinked `resourcePackage`; DEX files, ABI-to-library-file mappings,
assets and resources are optional. The producer supplies Android-compatible
bytecode and libraries, including their runtime dependencies. This adapter does
not compile arbitrary Linux programs into Android applications or relocate Nix
store references. Supported library ABI names are `x86`, `x86_64`, `armeabi-v7a`
and `arm64-v8a`. ELF class, byte order, shared-object type and machine are checked.

For bytecode that references resources, call `makeResourcePackage { manifest;
framework; resources; }` first. Its output contains `java/` with the generated
`R.java`, `R.txt`, and `base.apk`. Compile your DEX against those generated IDs,
then pass that output as `makeApplication { resourcePackage = linked; dexFiles =
[ myDex ]; ... }`. This avoids a circular resource/bytecode build dependency.

Outputs are deterministic **unsigned** APKs. Native libraries are uncompressed
and aligned to 16 KiB; other entries are aligned to four bytes. Use the native
signing helper outside Nix builds, keeping private signing keys outside the store:

```sh
android-impurifier sign unsigned.apk signed.apk --ks /private/release.p12
android-impurifier verify signed.apk
adb install signed.apk
```

The helper forwards signer options to upstream apksigner. Android's package
manager remains responsible for installation, signature policy and app data.

VM coverage uses a pinned Android-x86 9.0-r2 userspace under software QEMU. Its
fixture application contains real DEX and a Nix-built Android-targeted JNI library
without libc dependencies. Tests exercise native signature verification, package
installation, upgrade, persistent app data, JNI execution, rejected signer changes,
rejected tampering and uninstall. This fixture is not a claim of modern stock
Android, ARM device, split APK, app bundle or app-store publication coverage.

Original code is MIT; upstream tools and test images retain their own licenses.

The VM derives its boot image from the pinned upstream ISO, omitting only its
preinstalled Chrome and Google Play services APKs. Their unrelated first-boot
compilation and background work can starve the UI watchdog on small TCG runners.
The kernel, framework, package manager, native signature checks and test-app UI
remain real. Fixture UI animations are disabled to reduce unnecessary rendering.
