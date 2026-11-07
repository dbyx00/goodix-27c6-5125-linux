#!/usr/bin/env python3
"""Read-only Goodix 27c6:5125 probe.

Sends only volatile/read commands:
  nop, enable_chip, nop, firmware_version, read_sensor_register(0x0000),
  read_otp, query_mcu_state, preset_psk_read(0xbb020003)

It never calls reset, write_sensor_register, upload_config_mcu,
preset_psk_write, mcu_erase_app, write_firmware or any firmware command.
"""

import json
import os
import sys
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
CANDIDATES = [
    os.path.join(HERE, "vendor", "goodix_fp_dump"),
    os.path.join(HERE, "..", "upstream", "goodix-fp-dump"),
]
for candidate in CANDIDATES:
    if os.path.isdir(candidate):
        sys.path.insert(0, os.path.abspath(candidate))
        break
else:
    raise SystemExit("goodix-fp-dump helpers not found")

import goodix  # noqa: E402
import protocol  # noqa: E402


def hexs(value):
    if value is None:
        return None
    if isinstance(value, (bytes, bytearray)):
        return value.hex()
    return value


def main():
    result = {
        "device": "27c6:5125",
        "firmware": None,
        "chip_id": None,
        "otp": None,
        "mcu_state": None,
        "psk_read_ok": None,
        "psk_flags": None,
        "psk_hash": None,
        "error": None,
    }

    dev = None
    try:
        dev = goodix.Device(0x5125, protocol.USBProtocol, timeout=10)
        dev.nop()
        dev.enable_chip(True)
        dev.nop()
        # Volatile sensor reset, same payload as the libfprint driver
        # (0x05, 20). It does not touch firmware, OTP or the PSK.
        reset_result = dev.reset(True, False, 20)
        result["reset"] = reset_result

        result["firmware"] = dev.firmware_version()
        result["chip_id"] = hexs(dev.read_sensor_register(0x0000, 4))
        result["otp"] = hexs(dev.read_otp())
        result["mcu_state"] = hexs(dev.query_mcu_state(b"\x55", True))

        ok, flags, psk = dev.preset_psk_read(0xBB020003)
        result["psk_read_ok"] = bool(ok)
        result["psk_flags"] = hexs(flags) if isinstance(flags, int) else flags
        result["psk_hash"] = hexs(psk)

    except Exception as exc:  # noqa: BLE001
        result["error"] = f"{type(exc).__name__}: {exc}"
        traceback.print_exc()

    print("PROBE_JSON:" + json.dumps(result, sort_keys=True))
    return 0 if result["error"] is None else 1


if __name__ == "__main__":
    sys.exit(main())
