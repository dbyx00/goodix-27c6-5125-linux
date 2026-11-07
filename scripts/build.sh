#!/usr/bin/env bash
# Build the goodix5125 libfprint driver into a private prefix.
# Run as root (the install step needs /opt and systemd), or use --build-only
# as a normal user with a writable prefix.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/.cache/libfprint-mr648"
BUILD="${SRC}/build"
PREFIX="${PREFIX:-/opt/goodix-27c6-5125}"
PIN="8cef588bcf165ebf866bbb526b1d1f116888d4af"
UPSTREAM="https://gitlab.freedesktop.org/libfprint/libfprint.git"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need() {
    command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

deps_debian() {
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        build-essential meson ninja-build pkg-config git \
        libglib2.0-dev libgio-2.0-dev libgudev-1.0-dev libgusb-dev \
        libusb-1.0-0-dev libssl-dev libudev-dev libpixman-1-dev \
        libcairo2-dev systemd-dev python3-usb
}

deps_fedora() {
    dnf install -y \
        gcc make meson ninja-build pkgconf-pkg-config git \
        glib2-devel gudev-devel libgusb-devel libusb1-devel openssl-devel \
        systemd-devel pixman-devel cairo-devel python3-pyusb
}

deps_arch() {
    pacman -S --needed --noconfirm \
        base-devel meson ninja pkgconf git glib2 libgudev gusb libusb \
        openssl systemd systemd-libs pixman cairo python-pyusb
}

deps_suse() {
    zypper --non-interactive install \
        gcc make meson ninja pkg-config git glib2-devel libgudev-1_0-devel \
        libgusb-devel libusb-1_0-devel libopenssl-devel systemd-devel \
        libpixman-1-0-devel cairo-devel python3-pyusb
}

install_deps() {
    if command -v apt-get >/dev/null 2>&1; then deps_debian
    elif command -v dnf >/dev/null 2>&1; then deps_fedora
    elif command -v pacman >/dev/null 2>&1; then deps_arch
    elif command -v zypper >/dev/null 2>&1; then deps_suse
    else
        die "unknown package manager; install: meson ninja gcc pkg-config glib2 gusb gudev libusb openssl udev pixman cairo"
    fi
}

if [[ "${1:-}" == "--deps" ]]; then
    install_deps
    shift
fi

need git
need meson
need ninja

mkdir -p "${ROOT}/.cache"

if [[ ! -d "${SRC}/.git" ]]; then
    log "cloning libfprint MR !648 into ${SRC}"
    mkdir -p "${SRC}"
    git -C "${SRC}" init -q
    git -C "${SRC}" remote add origin "${UPSTREAM}"
fi

log "fetching pinned MR head ${PIN}"
git -C "${SRC}" fetch -q --depth 1 origin refs/merge-requests/648/head
git -C "${SRC}" checkout -q -f FETCH_HEAD

HEAD="$(git -C "${SRC}" rev-parse HEAD)"
if [[ "${HEAD}" != "${PIN}" ]]; then
    log "warning: MR head is ${HEAD}, expected ${PIN}; continuing with the head"
fi

log "configuring (prefix=${PREFIX})"
rm -rf "${BUILD}"
meson setup "${BUILD}" "${SRC}" \
    --prefix="${PREFIX}" \
    --libdir=lib \
    -Ddrivers=goodix5125 \
    -Ddoc=false \
    -Dgtk-examples=false \
    -Dintrospection=false

log "compiling"
meson compile -C "${BUILD}"

log "running unit tests"
"${BUILD}/tests/test-goodix5125"
"${BUILD}/tests/test-goodix5125-tls"

log "building the offline PSK-hash helper"
cc -O2 \
    -I"${SRC}/libfprint/drivers/goodix5125" \
    -o "${ROOT}/tools/zero_psk_hash" \
    "${ROOT}/tools/zero_psk_hash.c" \
    "${SRC}/libfprint/drivers/goodix5125/goodix5125-pairing.c" \
    $(pkg-config --cflags --libs gio-2.0 glib-2.0 openssl)

log "installing into ${PREFIX}"
meson install -C "${BUILD}"
log "build complete"
