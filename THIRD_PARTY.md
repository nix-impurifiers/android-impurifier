# Third-party material

Original adapter code is MIT. Tools are dependencies, not relicensed by this repo:
AOSP aapt2 and apksigner (Apache-2.0), Smali/dexlib2 (BSD-3-Clause), their pinned
Maven dependencies (upstream licenses), OpenJDK (GPL with Classpath Exception),
and QEMU (GPL and other upstream component licenses).

The Android-x86 9.0-r2 ISO is a test fixture, downloaded by URL and hash. It
contains Android, the Linux kernel and other upstream components under their
respective licenses. It is not included in emitted application APKs. Native
payload producers remain responsible for their input code and dependency notices.

The derived VM boot ISO removes `/app/Chrome/Chrome.apk` and
`/priv-app/GmsCore/GmsCore.apk`, zeros the released filesystem blocks and replaces
`system.sfs` through xorriso while preserving the remaining ISO content. Android
framework resources are read from the original system image. This fixture change
reduces unrelated cold-boot work; it does not replace package-manager code, disable
certificate verification or modify the tested application APKs.
