# SPDX-License-Identifier: MIT
{ pkgs }:
let
  jars = map (entry: pkgs.fetchurl { inherit (entry) url hash; }) (
    builtins.fromJSON (builtins.readFile ./smali-jars.json)
  );
in
pkgs.writeShellApplication {
  name = "smali";
  runtimeInputs = [ pkgs.jre_headless ];
  text = ''exec java -cp ${pkgs.lib.escapeShellArg (pkgs.lib.concatStringsSep ":" (map toString jars))} org.jf.smali.Main "$@"'';
}
