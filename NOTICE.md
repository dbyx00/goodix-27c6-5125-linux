# Third-party notices

This project builds and installs a libfprint driver derived from the
`goodix5125` merge request:

- libfprint upstream: <https://gitlab.freedesktop.org/libfprint/libfprint>
- MR !648: <https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/648>
- Author branch: <https://gitlab.freedesktop.org/Thomas97460/libfprint>
  (`goodix-5125-oem-image`, pinned commit `8cef588bcf165ebf866bbb526b1d1f116888d4af`)

The ChicagoHS computational backend under
`libfprint/drivers/goodix5125/chicago/` comes from:

- <https://github.com/berkekbgz/libfprint-goodix-spi>
  revision `010a665f54089a1632b1ab7be588b316ace934e2`
- Copyright (C) 2026 Berke Kabagöz
- LGPL-2.1-or-later

The white-box pairing primitive is adapted from the same source and retains
its notices.

The read-only probe uses protocol helpers from:

- <https://github.com/goodix-fp-linux-dev/goodix-fp-dump>
- MIT license
- Copyright the goodix-fp-linux-dev authors
- The vendored copy under `tools/vendor/goodix_fp_dump/` has one local change:
  the SPI-only `periphery`/`spidev` imports are optional, so the USB probe
  works on systems without SPI Python bindings.

Independent protocol and driver work that informed this project:

- Rockytkg, `goodix-linux-27c6-5125` (GPL-2.0-or-later)
- sorguido, `goodix-27c6-5125` (GPL-2.0-or-later/GPL-3.0-or-later)
- arbnorme, `libfprint-goodix5125` (LGPL-2.1-or-later)
- The `goodix-fp-linux-dev` community

No vendor firmware, proprietary DLL, PSK, OTP, fingerprint image or template is
distributed by this project. The Windows driver package and the Windows ISO are
downloaded separately for testing and are not part of this repository.
