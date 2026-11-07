# Packaging

The driver is a patched libfprint. Packaging therefore has two possible shapes:

1. **Private prefix (default, safest):** install libfprint in
   `/opt/goodix-27c6-5125` and add an fprintd systemd drop-in. No distro
   package is replaced. This is what `scripts/install.sh` does.
2. **Distro package (optional):** build a package that replaces the distro
   `libfprint` with the patched one. This is smaller but conflicts with the
   distro package and must be re-done after every libfprint update.

Until MR !648 is merged upstream, the private prefix is the recommended path.

## Planned recipes

| Distro | Recipe | Status |
|---|---|---|
| Debian/Ubuntu | `packaging/deb/` | TODO |
| Fedora | `packaging/rpm/goodix-27c6-5125.spec` | TODO |
| Arch | `packaging/arch/PKGBUILD` | TODO |
| openSUSE | `packaging/rpm/` | TODO |
| NixOS | `packaging/nix/flake.nix` | TODO |

## Package contents

- The private libfprint build.
- The udev rule.
- The fprintd drop-in.
- `goodix-ctl`, the probe and the PSK hash helper.
- Documentation and licenses.
- **No firmware, PSK, OTP, images or templates.**

## Versioning

Pin the libfprint source to the MR commit recorded in
`scripts/build.sh` (`8cef588…`). Bump it only after re-running the hardware
validation in `docs/validation.md`.
