# Windows / Linux coexistence

## The PSK model

The Goodix `27c6:5125` does not store fingerprints. It stores a write-only
102-byte container and exposes `SHA-256(container)` at register
`0xbb020003`. The real 32-byte TLS PSK is kept by the host.

- Windows generates a random PSK per Windows installation, writes the wrapped
  container to the sensor, and seals the plaintext with DPAPI in
  `Goodix_Cache.bin`.
- The Linux driver keeps its plaintext PSK in
  `/var/lib/fprint/goodix5125/psk` (mode 0600).
- The sensor can hold only one pairing container at a time.

Consequences:

| Situation | Result |
|---|---|
| Sensor paired by this Linux host | Driver uses the stored PSK; no write |
| Sensor blank / PSK zero | Driver generates a PSK, writes once, verifies the hash |
| Sensor paired by Windows | Driver refuses to overwrite; import the Windows PSK or re-provision |
| Windows boots after a Linux PSK change | Windows sees a different hash and must re-pair/re-enroll |

Fingerprint templates are independent: Windows Hello stores its own templates,
Linux stores its own under `/var/lib/fprint`.

## The safe paths

### A. Import the Windows PSK (best for dual boot)

1. Recover the PSK offline from the Windows installation (read-only), for
   example from `Goodix_Cache.bin` plus the DPAPI SYSTEM/SECURITY hives.
2. Verify it offline: `SHA256(whitebox(psk))` must equal the sensor hash
   reported by `goodix-ctl probe`.
3. Install it as `/var/lib/fprint/goodix5125/psk` (0600).
4. Linux uses it without writing; Windows keeps working.

This project only documents the procedure; it does not ship a Windows secret
extractor, and it never publishes a PSK.

### B. Re-provision from Linux (no Windows installation)

1. Record the current sensor hash, OTP and firmware version.
2. Make sure the sensor runs a firmware that accepts PSK writes
   (APP12508 is tested).
3. Authorize one replacement:

   ```sh
   sudo GOODIX5125_PROVISION_PSK=random systemctl restart fprintd
   ```

   The driver generates a random PSK, persists it atomically, writes the
   container, reads the hash back and verifies it before using TLS.
4. Enroll on Linux.
5. Windows will need to generate its own PSK and re-enroll the next time it
   runs. This is a re-pairing, not a brick: the firmware is untouched.

### C. Keep the sensor read-only (diagnostics)

`goodix-ctl probe` and `goodix-ctl status` never write. Use them before any
decision.

## Firmware warning

Do **not** flash firmware. The documented brick cases come from flashing a
firmware image that does not match the key format, not from changing the PSK.

The Windows driver packages differ:

| Windows driver | Embedded ST411SEC firmware | Safe for a 12508 sensor? |
|---|---|---|
| 1.1.125.13 | `GF_ST411SEC_APP_12508` | Yes, version matches; no update |
| 1.1.125.14 | `GF_ST411SEC_APP_12509` | May update 12508 -> 12509 |
| 1.1.125.20 | `GF_ST411SEC_APP_12512` | May update; not tested with this driver |

If you test Windows, prefer 1.1.125.13 on a 12508 unit and keep a note of the
firmware before/after.

## Validation checklist

- [ ] `goodix-ctl probe` reports firmware and sensor hash.
- [ ] Driver refuses a foreign pairing with no write.
- [ ] Linux re-provision writes a random PSK and verifies the hash.
- [ ] Linux enroll/verify works.
- [ ] A fresh Windows install can initialize the sensor and enroll.
- [ ] (Dual boot) Windows after a Linux PSK change re-pairs or documents the
      exact recovery procedure.

Results are recorded in [validation.md](validation.md).
