# SPDX-License-Identifier: MIT
{ pkgs }:
let
  inherit (pkgs) lib;
  # Link resources before compiling DEX, so producers can compile against generated R.java.
  makeResourcePackage =
    {
      manifest,
      framework,
      resources ? null,
      name ? "android-resources",
    }:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.aapt ]; } ''
      mkdir -p "$out/java"
      ${lib.optionalString (
        resources != null
      ) "aapt2 compile --dir ${lib.escapeShellArg (toString resources)} -o resources.zip"}
      aapt2 link --manifest ${lib.escapeShellArg (toString manifest)} -I ${lib.escapeShellArg (toString framework)} \
        --java "$out/java" --output-text-symbols "$out/R.txt" -o "$out/base.apk" \
        ${lib.optionalString (resources != null) "resources.zip"}
    '';
  makeApplication =
    {
      manifest ? null,
      framework ? null,
      resourcePackage ? null,
      dexFiles ? [ ],
      nativeLibraries ? { },
      assets ? null,
      resources ? null,
      name ? "android-application",
    }:
    assert lib.assertMsg (
      builtins.match "[A-Za-z0-9_.+-]+" name != null
      && !lib.elem name [
        "."
        ".."
      ]
    ) "invalid Android artifact name";
    assert lib.assertMsg (
      (resourcePackage == null && manifest != null && framework != null)
      || (resourcePackage != null && manifest == null && framework == null && resources == null)
    ) "supply either manifest/framework/resources or a prelinked resourcePackage";
    assert lib.assertMsg (lib.all (
      abi:
      lib.elem abi [
        "x86"
        "x86_64"
        "armeabi-v7a"
        "arm64-v8a"
      ]
    ) (builtins.attrNames nativeLibraries)) "unsupported Android native ABI";
    let
      linked =
        if resourcePackage != null then
          resourcePackage
        else
          makeResourcePackage {
            inherit manifest framework resources;
            name = "${name}-resources";
          };
      specification = pkgs.writeText "android-inputs.json" (
        builtins.toJSON { inherit dexFiles nativeLibraries assets; }
      );
    in
    pkgs.runCommand "${name}-unsigned.apk"
      {
        nativeBuildInputs = [
          pkgs.aapt
          pkgs.python3
        ];
      }
      ''
        python3 ${./assemble.py} ${linked}/base.apk ${specification} "$out"
      '';
  package = pkgs.writeShellApplication {
    name = "android-impurifier";
    runtimeInputs = [ pkgs.apksigner ];
    text = ''
      case "''${1:-}" in
        sign)
          shift
          if [ "$#" -lt 2 ]; then echo 'usage: android-impurifier sign INPUT OUTPUT [apksigner options]' >&2; exit 2; fi
          input=$1
          output=$2
          shift 2
          exec apksigner sign --out "$output" "$@" "$input"
          ;;
        verify) shift; exec apksigner verify --verbose "$@" ;;
        *) echo 'usage: android-impurifier sign INPUT OUTPUT [options] | verify APK' >&2; exit 2 ;;
      esac
    '';
  };
in
{
  inherit makeApplication makeResourcePackage package;
  nativeClient = pkgs.android-tools;
}
