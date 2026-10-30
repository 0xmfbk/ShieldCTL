# shieldctl

A single-file, dependency-light Bash tool that hardens, audits and monitors a Linux
desktop/laptop, with systemd-timer scheduling. No daemon, no network calls of its own.

Built from real-world hardening of Pop!_OS / Ubuntu 22.04. Tested with `shellcheck` and
a sandboxed test run; **test on your machine with `--dry-run` first**.

## Install

```bash
git clone https://github.com/<you>/shieldctl && cd shieldctl
sudo ./shieldctl self-install        # copies to /usr/local/bin
sudo shieldctl install               # lynis rkhunter clamav aide fail2ban auditd
```

## Use

```bash
shieldctl status                     # read-only dashboard
sudo shieldctl harden --dry-run      # preview
sudo shieldctl harden                # sysctl, module blacklist, coredumps, perms, firewall
sudo shieldctl rollback              # undo everything it changed
sudo shieldctl scan all              # updates, ports, rootkit, malware, integrity, audit
sudo shieldctl aide init --bg        # build file-integrity baseline in the background
sudo shieldctl schedule defaults     # daily updates, weekly scans, monthly Lynis
sudo shieldctl schedule add av "scan malware" "Mon *-*-* 03:00"
shieldctl schedule list
```

Opt-in modules (never run by default): `umask`, `dns` (DNS-over-TLS, auto-reverts if it
breaks resolution), `usbguard` (refuses to proceed if it could lock out your keyboard),
and `services disable <name>` (reversible).

## Safety design

- Every change is a drop-in file or a backed-up edit, undone by `rollback`.
- Kernel keys are test-applied; unsupported ones are skipped, never persisted.
- Permissions are only ever tightened.
- Deliberately untouched: `ip_forward` (libvirt/Docker), `kernel.modules_disabled`, `usb-storage`.
- Scheduled tasks are whitelisted; `aide update` is never scheduled (a baseline must be accepted by a human).
- AIDE baseline hash is recorded; a changed hash is reported as possible tampering.
- A scheduled task that finds a problem exits non-zero, so it shows in `systemctl --failed`
  and sends a desktop notification if `notify-send` exists.

## Limits (honest ones)

- Best support: Debian/Ubuntu family. Fedora/Arch/openSUSE: package install and checks are best-effort.
- It reduces attack surface and detects change; it cannot make a machine "unhackable".
- AIDE reports changes after normal package updates. Workflow: `aide check`, review,
  then `aide update`.
- rkhunter's online `--update` no longer works on Debian/Ubuntu; shieldctl does not use it.

MIT licensed.