#!/usr/bin/env bash
# Install the goodix5125 driver into a private prefix and wire fprintd to it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${PREFIX:-/opt/goodix-27c6-5125}"
DRIVER_DIR="/var/lib/fprint/goodix5125"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if [[ "${EUID}" -ne 0 ]]; then
    die "run as root: sudo $0 $*"
fi

"${ROOT}/scripts/build.sh" "$@"

log "installing udev rule"
install -Dm644 "${ROOT}/scripts/udev/70-goodix-27c6-5125.rules" \
    /etc/udev/rules.d/70-goodix-27c6-5125.rules

log "installing fprintd drop-in (private libfprint)"
install -d /etc/systemd/system/fprintd.service.d
cat > /etc/systemd/system/fprintd.service.d/50-goodix-27c6-5125.conf <<EOF
[Service]
Environment=LD_LIBRARY_PATH=${PREFIX}/lib
EOF

log "reloading systemd and udev"
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl try-restart fprintd || true
else
    log "systemd not found: start fprintd manually with LD_LIBRARY_PATH=${PREFIX}/lib"
fi

if command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules || true
    udevadm trigger --subsystem-match=usb --attr-match=idVendor=27c6 || true
fi

if command -v restorecon >/dev/null 2>&1; then
    restorecon -R "${PREFIX}" "${DRIVER_DIR}" 2>/dev/null || true
fi

log "installed"
cat <<EOF

Driver prefix : ${PREFIX}
State        : ${DRIVER_DIR}/psk (created on first pairing)
Next steps:
  sudo ${ROOT}/scripts/goodix-ctl status
  fprintd-enroll -f right-index-finger "\$USER"

If the sensor is paired to Windows and you have not imported its PSK, the
driver will refuse to overwrite it. Read docs/windows-coexistence.md first.

EOF
