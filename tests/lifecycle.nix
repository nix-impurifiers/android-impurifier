# SPDX-License-Identifier: MIT
{ pkgs, backend }:
let
  image = import ../nix/image.nix { inherit pkgs; };
  app = revision: import ./application.nix { inherit pkgs backend revision; };
in
pkgs.runCommand "android-native-package-lifecycle"
  {
    nativeBuildInputs = [
      pkgs.qemu
      pkgs.android-tools
      pkgs.python3
      pkgs.jdk_headless
      backend.package
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    for identity in trusted wrong; do
      keytool -genkeypair -keystore "$TMPDIR/$identity.p12" -storepass testpass -keypass testpass \
        -alias proof -dname CN=Ephemeral-VM-Test -keyalg RSA -keysize 2048 -validity 1
    done
    android-impurifier sign ${app "1"} one.apk --ks "$TMPDIR/trusted.p12" --ks-pass pass:testpass
    android-impurifier sign ${app "2"} two.apk --ks "$TMPDIR/trusted.p12" --ks-pass pass:testpass
    android-impurifier sign ${app "2"} wrong.apk --ks "$TMPDIR/wrong.p12" --ks-pass pass:testpass
    cp two.apk damaged.apk
    python3 - <<'PY'
    import zipfile
    with zipfile.ZipFile('damaged.apk', 'a') as archive:
        archive.writestr('assets/untrusted', b'changed after signing')
    PY
    export ONE_APK="$PWD/one.apk" TWO_APK="$PWD/two.apk" WRONG_APK="$PWD/wrong.apk" DAMAGED_APK="$PWD/damaged.apk"
    python3 ${./probe.py} ${image} ${image.iso} ${./lifecycle.py}
    touch "$out"
  ''
