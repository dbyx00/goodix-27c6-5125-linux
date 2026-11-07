# Windows recovery test harness

This directory contains the unattended Windows 11 test used to prove that a
Linux PSK change does not brick the sensor for Windows.

It does **not** contain the Windows ISO, the Goodix driver CAB, `gfusb.dll`,
`AlgoChicago.dll`, firmware, PSK, OTP or biometric data. Those are downloaded
separately and must not be committed.

## What it proves

- A fresh Windows installation installs the Goodix driver and reports the
  device as Started.
- After Linux re-provisions the sensor, a Windows installation that still has
  the old DPAPI cache re-provisions the sensor automatically.
- The sensor firmware is unchanged (use the 1.1.125.13 driver on a 12508 unit).

## Files

| File | Purpose |
|---|---|
| `autounattend.xml` | Unattended Windows 11 Enterprise Evaluation install, local admin `dby`, disables UAC and Windows Update driver search, runs the driver install from the `GOODIXDRV` CD |
| `install-goodix.cmd` | Installs `gfusb.inf` with `pnputil`, logs to `C:\goodix-test.log`, enumerates the biometric device |

The test password in `autounattend.xml` is disposable. Use a throwaway VM.

## Prepare the media

1. Download the official Windows 11 Enterprise Evaluation ISO (en-US, 64-bit).
2. Download the Goodix driver **1.1.125.13** from the Microsoft Update Catalog
   (`USB\VID_27C6&PID_5125`). Do not use 1.1.125.20 on a 12508 unit: it embeds
   `GF_ST411SEC_APP_12512` and may update the firmware.
3. Extract the CAB with `cabextract` and add `install-goodix.cmd` to the
   extracted directory.
4. Build the driver ISO:

   ```sh
   genisoimage -quiet -J -R -V GOODIXDRV -o goodix-driver.iso driver-dir/
   ```

5. Build the answer-file ISO:

   ```sh
   mkdir -p answer && cp autounattend.xml answer/
   genisoimage -quiet -J -R -V AUTOUNATTEND -o autounattend.iso answer/
   ```

6. Create a VM with UEFI, TPM 2.0, a SATA disk, the Windows ISO as the first
   CD, the answer ISO as a second CD, the driver ISO as a third CD, and the
   sensor passed through as `usb-host` (vendor `0x27c6`, product `0x5125`).

## Expected log

```
Adding driver package: gfusb.inf
Driver package added successfully.
Published Name: oem1.inf
Driver package installed on device: USB\VID_27C6&PID_5125\00000000001A
...
Device Description: Goodix Fingerprint USB Device
Class Name: Biometric
Manufacturer Name: Goodix FP
Status: Started
Driver Name: oem1.inf
```

The Windows C: volume may be BitLocker-encrypted. In that case read
`C:\goodix-test.log` from inside the VM (Notepad) instead of mounting the
qcow2 offline.

## Safety

- Do not flash firmware.
- Do not use a driver version whose embedded firmware differs from the sensor
  unless you accept a firmware update.
- Do not commit the ISO, CAB, DLLs or logs containing device data.
