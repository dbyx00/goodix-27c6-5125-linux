# Validation log

## Environment

| Item | Value |
|---|---|
| Date | 2026-11-07 |
| Laptop | HUAWEI CREM-WXX9 (MateBook 16, Ryzen 7 5800H) |
| Distro | Ubuntu 26.04 LTS, kernel 7.0.0-42-generic |
| Sensor | Goodix `27c6:5125` |
| Firmware | `GF_ST411SEC_APP_12508` (unchanged throughout) |
| Chip ID | `0x2504` |
| libfprint | MR !648, commit `8cef588bcf165ebf866bbb526b1d1f116888d4af` |
| fprintd | 1.94.5 |
| Windows test VM | Windows 11 Enterprise Evaluation 10.0.26300.9457, Goodix driver 1.1.125.13 |

OTP, PSK plaintext and biometric data are deliberately not recorded here.
PSK hashes below are `SHA256(whitebox(PSK))` prefixes; they are not secrets.

## 1. Read-only probe

- Firmware, chip ID and OTP read successfully.
- MCU state `01 02 30 …` (healthy family; the community-bricked example is
  `01 09 …`).
- Initial sensor PSK hash was non-zero and different from the all-zero PSK
  hash (`b5e0beeb…`). The sensor had been paired by the previous Windows
  installation.
- No PSK, OTP, configuration or firmware write was performed.

## 2. Foreign-pairing refusal

With no local PSK, the driver opened the device and refused to enroll:

```
The Goodix sensor is paired to another host, but
/var/lib/fprint/goodix5125/psk is missing; import its PSK or set
GOODIX5125_PROVISION_PSK=random once to replace the existing pairing
```

The sensor hash after the test was unchanged. This confirms the safety
behavior of MR !648.

## 3. Windows 11 baseline (PSK A)

A Windows 11 Enterprise Evaluation VM was installed with UEFI, TPM 2.0 and the
sensor passed through (`usb-host`). The Goodix Windows driver **1.1.125.13**
was installed from the Microsoft Update Catalog. It embeds
`GF_ST411SEC_APP_12508`, exactly matching the sensor, so it does not update the
firmware.

The `C:\goodix-test.log` produced by `pnputil` shows:

```
Driver package installed on device: USB\VID_27C6&PID_5125\00000000001A
...
Device Description: Goodix Fingerprint USB Device
Class Name: Biometric
Manufacturer Name: Goodix FP
Status: Started
Driver Name: oem1.inf
```

After Windows initialized the sensor, the sensor PSK hash changed from the
original foreign value to PSK A (`17b88028…`). Firmware remained
`GF_ST411SEC_APP_12508`.

## 4. Linux re-provision and enrollment (PSK B)

With the sensor paired to Windows, the Linux driver would refuse. The project
explicitly authorized one replacement:

```sh
GOODIX5125_PROVISION_PSK=random
```

The driver generated a PSK, persisted it atomically to
`/var/lib/fprint/goodix5125/psk` (32 bytes, mode 0600), wrote the container,
read the hash back and verified:

```
sensor hash : 9525ef22f42f91d727df3fa2f0ea21e846254f77eaa6160ff86ceabd25040b25
local hash  : 9525ef22f42f91d727df3fa2f0ea21e846254f77eaa6160ff86ceabd25040b25
```

Firmware remained `GF_ST411SEC_APP_12508`.

`fprintd-enroll -f right-index-finger dby` completed after the expected
12-stage policy. Several stages reported `enroll-finger-not-centered` (the
active area is only about 3 x 4 mm), then:

```
Enroll result: enroll-completed
```

## 5. Linux verification

| Test | Result |
|---|---|
| Same finger | `verify-match` |
| Different finger | `verify-no-match` |
| `fprintd-list` | right-index-finger enrolled |

## 6. Windows recovery after a Linux PSK change

The Windows VM was restored from the `windows-psk-a` snapshot, which still had
the stale PSK A cache, and booted with the sensor carrying Linux PSK B.

- Windows reported the device as **Started** (`oem1.inf`).
- After shutdown, the sensor hash was **C** (`2d3a4b86…`), i.e. Windows
  re-provisioned automatically.
- Firmware remained `GF_ST411SEC_APP_12508`.
- No firmware command was sent by the project at any point.

This is the key no-brick result: a Windows installation with a stale PSK
re-pairs instead of leaving the sensor unusable. The reproducible test harness
is in [`tests/windows/`](../tests/windows/). Windows fingerprints may still
need to be re-enrolled after the re-pair; the transport PSK and the templates
are separate.

## 7. Linux restore (PSK B again)

The Linux driver was authorized to write its persisted local PSK again:

- Sensor hash returned to PSK B (`9525ef22…`).
- The previously enrolled fingerprint still returned `verify-match`.

The template is independent of the transport PSK and survives the re-pair.

## 8. Final state

| Item | Value |
|---|---|
| Firmware | `GF_ST411SEC_APP_12508` |
| Sensor PSK | Linux PSK B (`9525ef22…`) |
| Local PSK file | 32 bytes, mode 0600, root:root |
| fprintd | active on demand; device and fingerprint listed |
| USB power control | `on`, `ID_AUTOSUSPEND=0` |
| `cdc_acm` | not loaded |

## 9. Limitations

- One physical unit, one user, one enrolled finger.
- No FAR/FRR estimate; the impersonator test is a single sample.
- Suspend/resume was not exercised on this unit; the udev rule keeps the
  sensor out of autosuspend but this is not a full qualification.
- The Windows test used a stale-cache installation (a stronger recovery case
  than a fresh install), but a second fresh installation was not repeated.
- Cross-distro build logic was exercised on Ubuntu 26.04 only; Fedora, Arch and
  openSUSE recipes are best-effort until tested.
- GDM has `pam_fprintd` configured by Ubuntu; enabling it for `sudo` is left to
  the user (`pam-auth-update --enable fprintd`).

## 10. Reproducing the probe

```sh
sudo ./scripts/goodix-ctl probe
```

The probe sends only nop, enable_chip, a volatile sensor reset,
firmware_version, read_sensor_register(0x0000), read_otp, query_mcu_state and
preset_psk_read. It never sends a PSK, OTP, configuration or firmware write.
