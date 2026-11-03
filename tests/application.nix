# SPDX-License-Identifier: MIT
{
  pkgs,
  backend,
  revision ? "1",
}:
let
  image = import ../nix/image.nix { inherit pkgs; };
  dex =
    pkgs.runCommand "android-proof.dex"
      { nativeBuildInputs = [ (import ../nix/smali.nix { inherit pkgs; }) ]; }
      ''
        smali assemble ${./Proof.smali} -o "$out"
      '';
  native =
    pkgs.runCommand "android-proof-${revision}.so"
      {
        nativeBuildInputs = [
          pkgs.llvmPackages.clang-unwrapped
          pkgs.llvmPackages.lld
        ];
      }
      ''
        cat > proof.c <<'C'
        __attribute__((visibility("default"))) int Java_org_niximpurifiers_Proof_value(void *env, void *klass) {
          (void)env; (void)klass;
          return ${revision};
        }
        C
        clang --target=x86_64-linux-android28 -fuse-ld=lld -nostdlib -shared -fPIC -O2 -Wl,-soname,libproof.so proof.c -o "$out"
      '';
  manifest = pkgs.writeText "AndroidManifest.xml" ''
    <manifest xmlns:android="http://schemas.android.com/apk/res/android"
      package="org.niximpurifiers.proof" android:versionCode="${revision}" android:versionName="${revision}">
      <uses-sdk android:minSdkVersion="28" android:targetSdkVersion="28" />
      <application android:label="@string/proof_name" android:debuggable="true" android:extractNativeLibs="false">
        <activity android:name="org.niximpurifiers.Proof" android:exported="true">
          <intent-filter>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
          </intent-filter>
        </activity>
      </application>
    </manifest>
  '';
  resources = pkgs.writeTextDir "values/strings.xml" ''
    <resources><string name="proof_name">Impurifier proof</string></resources>
  '';
  linked = backend.makeResourcePackage {
    inherit manifest resources;
    framework = "${image}/framework-res.apk";
  };

in
backend.makeApplication {
  name = "android-proof-${revision}";
  resourcePackage = linked;
  dexFiles = [ dex ];
  nativeLibraries.x86_64."libproof.so" = native;
}
