# Development

Run `nix flake check -L`. Tests require software QEMU, no KVM. The pinned Android
image and Maven tools are fetched by fixed hash; the production library accepts
its framework resources and producer-built DEX/libraries explicitly.

`tests/archive.nix` checks APK alignment and actual apksigner integrity policy.
`tests/lifecycle.nix` boots Android-x86, installs and upgrades signed applications,
executes DEX/JNI in Android's application sandbox, preserves app data, rejects
untrusted signing keys and tampering, and removes the application and its data.
Signing keys are ephemeral builder temporaries and are never copied to outputs.

The boot fixture must select `android_x86_64`, matching the image's hardware init
file. The fixture uses a conservative SSE4-capable CPU, 32-bit VESA mode
(`nomodeset vga=834`, 640×480×32), SwiftShader, four virtual CPUs and 4 GiB RAM. The old image's Bochs DRM/TTM
path can panic while dumping a SurfaceFlinger crash; the earlier 16-bit
VESA/maximum-feature CPU combination also crashed its SwiftShader framebuffer copier. This is fixture compatibility,
not an alteration to package signature policy. Virtual Wi-Fi is disabled so the
local ADB network uses the emulated Ethernet device. Android's policy routing needs a main-table rule for the local ADB test
network. Each run uses private server and forwarding ports. Continuous logcat
and kernel console output are retained in failure diagnostics. Serial console setup preserves case in public ADB keys. The test disables the preinstalled cloud scanner for ADB installs because the fixture
is offline. Android's package certificate/signature checks stay enabled and
are tested with mismatched keys and tampered APKs. Coverage currently targets API 28
x86_64; ARM and modern Android compatibility need separate native device coverage.
