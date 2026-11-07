# Installation notes

## What gets installed

| Path | Purpose |
|---|---|
| `/opt/goodix-27c6-5125/lib/libfprint-2.so.2*` | Private libfprint with the `goodix5125` driver |
| `/etc/systemd/system/fprintd.service.d/50-goodix-27c6-5125.conf` | `LD_LIBRARY_PATH` for fprintd only |
| `/etc/udev/rules.d/70-goodix-27c6-5125.rules` | Keep the sensor out of USB autosuspend |
| `/var/lib/fprint/goodix5125/psk` | Host PSK, created on first pairing, mode 0600 |
| `/var/lib/fprint/goodix5125/chicago-calibration.dat` | ChicagoHS calibration, bound to the OTP |

Your distro's libfprint and fprintd packages are not replaced.

## Quick install

```sh
sudo ./scripts/install.sh --deps
sudo ./scripts/goodix-ctl status
```

`--deps` installs the build dependencies for Debian/Ubuntu, Fedora, Arch or
openSUSE. Omit it if they are already installed.

## Manual build

```sh
sudo ./scripts/build.sh
```

This fetches the pinned MR !648 head into `.cache/libfprint-mr648`, builds with
`-Ddrivers=goodix5125`, runs the protocol/calibration/pairing unit tests, builds
the offline PSK hash helper, and installs into `/opt/goodix-27c6-5125`.

To change the prefix:

```sh
sudo PREFIX=/usr/local ./scripts/install.sh
```

## fprintd integration

The drop-in contains:

```ini
[Service]
Environment=LD_LIBRARY_PATH=/opt/goodix-27c6-5125/lib
```

Check that fprintd really loads the private library:

```sh
sudo systemctl stop fprintd
sudo env LD_LIBRARY_PATH=/opt/goodix-27c6-5125/lib \
  ldd /usr/libexec/fprintd | grep fprint
```

The first line should point to `/opt/goodix-27c6-5125/lib/libfprint-2.so.2`.
The daemon path may be `/usr/lib/fprintd` on some distributions.

## Non-systemd distributions

The driver itself is portable. If your distro does not use systemd, start
fprintd with the private library, for example:

```sh
LD_LIBRARY_PATH=/opt/goodix-27c6-5125/lib /usr/libexec/fprintd
```

and add the udev rule through your udev manager. Provide a service wrapper for
OpenRC/runit/s6 if you want it at boot.

## NixOS

A flake/module is planned. The clean approach is to override the `libfprint`
package with the MR !648 source and `-Ddrivers=goodix5125`, then pass that
package to `services.fprintd`. The private `/opt` layout is not used on NixOS.

## SELinux / AppArmor

- Fedora: `restorecon -Rv /opt/goodix-27c6-5125 /var/lib/fprint/goodix5125`.
- If fprintd has an AppArmor profile, allow read access to the private library
  and read/write access to `/var/lib/fprint/goodix5125`.
- The ChicagoHS backend is native C, so `MemoryDenyWriteExecute=true` stays
  enabled. No JIT or vendor DLL is needed.

## Optional: fingerprint for sudo/login

Ubuntu already ships `/etc/pam.d/gdm-fingerprint` with `pam_fprintd` for GDM.
To also use the fingerprint reader for `sudo` and other PAM services:

```sh
sudo pam-auth-update --enable fprintd
```

Keep the password fallback enabled. Test with `sudo -k; sudo -v` before relying
on it for login.

## Uninstall

```sh
sudo ./scripts/uninstall.sh
```

Templates and the pairing key are kept. To remove the pairing state:

```sh
sudo ./scripts/uninstall.sh --purge
```

`--purge` does not delete templates. Use `--purge --all-templates` only if you
want to remove fingerprints for every device on the system.
