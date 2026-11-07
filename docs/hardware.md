# Hardware and probe notes

## Unit under test

| Field | Value |
|---|---|
| Laptop | HUAWEI CREM-WXX9 (MateBook 16, Ryzen 7 5800H) |
| USB ID | `27c6:5125` |
| Manufacturer/product | Shenzhen Goodix Technology / Goodix Fingerprint Device |
| USB class | CDC Communications + CDC Data, bulk 64-byte endpoints |
| Speed | Full Speed (12 Mbps) |
| Chip ID | `0x2504` (ChicagoHS) |
| Firmware | `GF_ST411SEC_APP_12508` |
| Image | 80 x 64, 12-bit packed |
| OTP | 64 bytes, read successfully (not published) |
| MCU state | healthy (`01 02 …`; the bricked example in the community is `01 09 …`) |
| Initial PSK | non-zero, foreign (different from the all-zero PSK hash) |

The read-only probe sends only: nop, enable_chip, a volatile sensor reset,
firmware_version, read_sensor_register(0x0000), read_otp, query_mcu_state and
preset_psk_read. No PSK, OTP, configuration or firmware write is performed.

## All-zero PSK hash

The white-box algorithm is deterministic. The hash of the all-zero 32-byte PSK
computed with the driver's pairing code is:

```
b5e0beeb94c84eb99b883abd5c251073c56b91035c562a91a46c7f3349c36c89
```

This value is useful only to distinguish a blank/zero-PSK sensor from one that
has been paired by Windows. It is not a secret and it is not a PSK.

## USB layout

- Interface 0: CDC Communications, interrupt IN endpoint `0x82`.
- Interface 1: CDC Data, bulk OUT `0x01`, bulk IN `0x81`.
- The driver claims interface 1. `cdc_acm` must not be bound to interface 0;
  on the tested Ubuntu 26.04 system it is not loaded.

## Driver refusal test

With no local PSK and a sensor whose hash is non-zero, opening the device
produces:

```
The Goodix sensor is paired to another host, but
/var/lib/fprint/goodix5125/psk is missing; import its PSK or set
GOODIX5125_PROVISION_PSK=random once to replace the existing pairing
```

The sensor hash is unchanged after this test. This is the safety property the
project relies on.
