#!/usr/bin/env bash
# Remove the private driver installation. Templates and pairing state are kept
# unless --purge is given.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${PREFIX:-/opt/goodix-27c6-5125}"
PURGE=0
[[ "${1:-}" == "--purge" ]] && PURGE=1

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if [[ "${EUID}" -ne 0 ]]; then
    die "run as root: sudo $0"
fi

log "removing fprintd drop-in and udev rule"
rm -f /etc/systemd/system/fprintd.service.d/50-goodix-27c6-5125.conf
rm -f /etc/systemd/system/fprintd.service.d/60-goodix-provision.conf
rmdir /etc/systemd/system/fprintd.service.d 2>/dev/null || true
rm -f /etc/udev/rules.d/70-goodix-27c6-5125.rules

if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl try-restart fprintd || true
fi
if command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules || true
fi

log "removing ${PREFIX}"
rm -rf "${PREFIX}"

if [[ "${PURGE}" -eq 1 ]]; then
    log "purging pairing state and templates"
    rm -rf /var/lib/fprint/goodix5125
    # This removes templates for every fingerprint device on the system.
    if [[ "${2:-}" == "--all-templates" ]]; then
        rm -rf /var/lib/fprint/*
    fi
fi

log "done"
cat <<EOF

Your distro libfprint/fprintd packages were not modified.
Pairing state and templates were $( [[ "${PURGE}" -eq 1 ]] && echo "removed" || echo "kept" ).

EOF
