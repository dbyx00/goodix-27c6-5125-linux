# goodix-27c6-5125-linux

Cross-distribution Linux support for the **Goodix `27c6:5125`** fingerprint
reader found in Huawei MateBook 16 / MateBook 14 / MateBook D15 and Honor
MagicBook laptops.

> **Status: experimental, community driver.** It is based on the libfprint
> merge request [!648](https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/648)
> by Thomas97460, which is not merged upstream yet. Tested on a Huawei
> MateBook 16 (CREM-WXX9, Ryzen 7 5800H) with firmware
> `GF_ST411SEC_APP_12508`.
>
> **No firmware is ever flashed.** The driver refuses to overwrite a
> fingerprint-reader pairing (PSK) that belongs to another operating system
> unless you explicitly ask for it.

## Supported hardware

| Field | Value |
|---|---|
| USB ID | `27c6:5125` |
| Sensor | Goodix ChicagoHS, chip ID `0x2504` |
| Image | 80 x 64 px, host-side matching |
| Firmware tested | `GF_ST411SEC_APP_12508` |
| Laptops reported | MateBook 16 CREM-WXX9, MateBook 14, MateBook D15, Honor MagicBook 16 |

The driver checks the chip ID and refuses other sensors. It does not expose
firmware-update or storage-erase commands.

## What this project adds

- A reproducible build of the `goodix5125` libfprint driver on any distro.
- A private libfprint installation (`/opt/goodix-27c6-5125`) and a narrow
  fprintd drop-in, so your distro's libfprint is not replaced.
- A read-only probe (`goodix-ctl probe`) that reports firmware, chip ID and
  whether the sensor is already paired.
- A safe workflow for Windows coexistence: detect a foreign pairing, import a
  known PSK, or explicitly re-provision.
- udev rules that keep the sensor out of USB autosuspend.
- An installer with dependency recipes for Debian/Ubuntu, Fedora, Arch and
  openSUSE; distro packages and NixOS are on the roadmap.

## Requirements

- Linux with fprintd 1.94.x (tested) or a compatible version.
- Python 3 for the read-only probe.
- Build dependencies: meson, ninja, gcc, pkg-config, glib2, gusb, gudev,
  libusb, OpenSSL, udev, pixman (see `scripts/install.sh --deps`).

## Install (from a checkout)

```sh
git clone https://github.com/dbyx00/goodix-27c6-5125-linux.git
cd goodix-27c6-5125-linux

# 1. Read-only check. No writes.
sudo ./scripts/goodix-ctl probe

# 2. Build and install the driver in /opt.
sudo ./scripts/install.sh

# 3. Restart fprintd and enroll.
sudo systemctl restart fprintd
fprintd-enroll -f right-index-finger "$USER"
fprintd-verify "$USER"
```

`install.sh` builds libfprint with `-Ddrivers=goodix5125` into
`/opt/goodix-27c6-5125`, installs an fprintd drop-in with
`LD_LIBRARY_PATH=/opt/goodix-27c6-5125/lib`, adds the udev rule and reloads
the service. Your distro packages are not modified.

To remove everything:

```sh
sudo ./scripts/uninstall.sh
```

Templates under `/var/lib/fprint` and the pairing key under
`/var/lib/fprint/goodix5125` are kept unless you ask to delete them.

## Pairing and Windows coexistence

The sensor stores a write-only 102-byte container and exposes
`SHA-256(container)`. The host keeps the 32-byte PSK in
`/var/lib/fprint/goodix5125/psk` (mode 0600).

- **Blank sensor:** the driver generates a random PSK, saves it before writing,
  provisions the sensor, and verifies the returned hash.
- **Sensor paired by this host:** the key is used without writing.
- **Sensor paired by Windows or another host:** the driver **refuses** to
  overwrite it. Import the matching PSK into the path above, or explicitly
  authorize one replacement:

  ```sh
  sudo GOODIX5125_PROVISION_PSK=random systemctl restart fprintd
  # then enroll again; Windows will have to re-pair/re-enroll
  ```

Changing the PSK does **not** change the firmware. A fresh Windows install can
generate and provision its own PSK later. See
[docs/windows-coexistence.md](docs/windows-coexistence.md).

## Safety rules

1. Never flash firmware. The driver deliberately has no firmware-update code.
2. Never overwrite a foreign pairing without a backup and an explicit
   `GOODIX5125_PROVISION_PSK=random`.
3. Never publish firmware, PSK, OTP, fingerprint images or templates.
4. Keep a password fallback enabled in PAM and in your desktop.

## How it works

- Initialization is volatile: enable, reset, read chip ID `0x2504`, read and
  validate the 64-byte OTP, apply a 224-byte sensor configuration.
- The host acts as a TLS 1.2 PSK server; the sensor is the client, using
  `TLS_PSK_WITH_AES_128_GCM_SHA256` over the Goodix USB framing.
- Images are 7,680 packed bytes (80 x 64, 12-bit), transposed and passed to the
  bundled **ChicagoHS** engine (LGPL, from `berkekbgz/libfprint-goodix-spi`).
- There is no OEM `goodix.dat`; calibration is captured on every cold session.

## Troubleshooting

- **`fprintd` says "No devices available":** check `goodix-ctl probe` and
  `systemctl status fprintd`; ensure the drop-in is installed.
- **"paired to another host":** import the PSK or re-provision explicitly.
- **Enrollment times out / no image:** keep the sensor out of autosuspend
  (the udev rule does this), and do not press the power button. On MateBook
  the sensor is in the power button: **rest your finger lightly**.
- **Verify fails too often:** enroll the same finger from several positions;
  the active area is only about 3 x 4 mm.
- **Suspend/resume:** the driver re-initializes on resume; if it fails, reload
  `fprintd` and report the logs.

## Validation

Tested on one Huawei MateBook 16 (CREM-WXX9) running Ubuntu 26.04:

- Read-only probe: firmware `GF_ST411SEC_APP_12508`, chip `0x2504`, healthy
  MCU state, sensor paired by the previous Windows installation.
- Foreign-pairing refusal: the driver refused to overwrite the Windows PSK and
  the sensor hash was unchanged.
- Linux re-provision: new PSK written and verified against the sensor hash;
  firmware unchanged.
- Enrollment: 12 stages, `enroll-completed`.
- Verification: same finger `verify-match`, different finger
  `verify-no-match`.
- Windows 11 VM with a stale PSK: the device came back as **Started** and
  Windows re-provisioned the sensor automatically. No brick, firmware still
  `12508`.
- Linux restore: the persisted PSK was written back and the existing template
  still returned `verify-match`.

Details, limitations and the exact commands are in
[docs/validation.md](docs/validation.md). The reproducible Windows recovery harness
is in [tests/windows/](tests/windows/). The project does not claim FAR/FRR
numbers from a single device.

## Credits

- Thomas97460 and the libfprint MR !648 authors.
- Berke Kabagöz (`berkekbgz/libfprint-goodix-spi`) for the ChicagoHS backend.
- The `goodix-fp-linux-dev` community and `goodix-fp-dump`.
- Rockytkg, sorguido and arbnorme for independent protocol work.
- libfprint and fprintd upstream.

## License

Project scripts and documentation: GPL-2.0-or-later. The driver and the
vendored libfprint sources keep their per-file licenses, predominantly
LGPL-2.1-or-later. See [NOTICE.md](NOTICE.md).

---

## Resumen en español

Soporte Linux para el lector de huellas **Goodix `27c6:5125`** de Huawei
MateBook 16 (CREM-WXX9) y modelos relacionados. Está basado en el merge
request !648 de libfprint, todavía no fusionado.

- **Nunca flashea firmware.**
- **No sobrescribe la PSK de Windows** salvo que lo pidas explícitamente.
- Instala libfprint en `/opt/goodix-27c6-5125` y no toca la librería del sistema.
- Incluye sonda de solo lectura, reglas udev y scripts de instalación y
  desinstalación.
- Probado en firmware `GF_ST411SEC_APP_12508`; el sensor está en el botón de
  encendido: **apoya el dedo, no lo aprietes**.

Detalles de convivencia con Windows en
[docs/windows-coexistence.md](docs/windows-coexistence.md).
