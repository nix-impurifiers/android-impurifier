# SPDX-License-Identifier: MIT
{ pkgs, backend }:
let
  application = import ./application.nix { inherit pkgs backend; };
in
pkgs.runCommand "android-application-archive-contract"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.jdk_headless
      backend.package
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    keytool -genkeypair -keystore "$TMPDIR/test.p12" -storepass testpass -keypass testpass \
      -alias proof -dname CN=Ephemeral-VM-Test -keyalg RSA -keysize 2048 -validity 1
    android-impurifier sign ${application} signed.apk --ks "$TMPDIR/test.p12" --ks-pass pass:testpass
    android-impurifier verify signed.apk
    python3 - ${application} signed.apk <<'PY'
    import struct, sys, zipfile
    for path in sys.argv[1:]:
        with open(path, 'rb') as stream, zipfile.ZipFile(path) as archive:
            assert 'AndroidManifest.xml' in archive.namelist()
            assert archive.read('classes.dex').startswith(b'dex\n')
            library = archive.getinfo('lib/x86_64/libproof.so')
            stream.seek(library.header_offset)
            header = stream.read(30)
            namesize, extrasize = struct.unpack_from('<HH', header, 26)
            assert (library.header_offset + 30 + namesize + extrasize) % 16384 == 0
            assert library.compress_type == zipfile.ZIP_STORED
            assert not any('/nix/' in name for name in archive.namelist())
    PY
    cp signed.apk damaged.apk
    python3 - <<'PY'
    import zipfile
    with zipfile.ZipFile('damaged.apk', 'a') as archive:
        archive.writestr('assets/changed', b'untrusted change')
    PY
    if android-impurifier verify damaged.apk; then
      echo 'signature verifier accepted changed payload' >&2
      exit 1
    fi
    touch "$out"
  ''
