# shieldctl

![Platform](https://img.shields.io/badge/platform-Linux-111827)
![Shell](https://img.shields.io/badge/shell-Bash-4EAA25)
![License](https://img.shields.io/badge/license-MIT-blue)

**shieldctl** is a single-file Linux hardening, auditing, integrity-monitoring, and
scheduling utility. It applies conservative security improvements, explains what it
finds, records task results, and keeps changes easy to review and undo.

It is designed for administrators who want a practical command-line security baseline
without installing a permanent shieldctl daemon or sending data to an external service.

> **Important:** shieldctl reduces attack surface and improves visibility. It does not
> make a system invulnerable. Read the changes, test with `--dry-run`, and keep a
> recovery path before applying hardening to a production machine.

## Highlights

- Kernel and network hardening through tested `sysctl` values
- Conservative kernel-module blocking
- Core-dump restrictions
- Safer permissions for selected security-sensitive paths
- Optional firewall, DNS-over-TLS, USBGuard, umask, and service hardening
- Lynis, rkhunter, ClamAV, AIDE, update, and network-listener checks
- AIDE baseline hashing to detect baseline tampering
- Reversible drop-in files, backups, manifests, and rollback support
- systemd timer scheduling with a strict task allowlist
- Human-readable status, reports, logs, exit codes, and desktop notifications
- No shieldctl daemon and no shieldctl-owned network service

## Requirements

- Linux with Bash 4+
- `systemd` is recommended for service checks, scheduling, and background AIDE jobs
- Root access for hardening, installation, scans, rollback, and schedules
- One supported package manager for installation:
  - `apt-get` — Debian, Ubuntu, Pop!_OS, Linux Mint, and derivatives
  - `dnf` — Fedora and compatible distributions
  - `pacman` — Arch Linux and derivatives
  - `zypper` — openSUSE and compatible distributions

Most checks degrade gracefully when optional tools are unavailable. The strongest
integration is expected on Debian-family systems; Fedora, Arch, and openSUSE use
best-effort package and service mappings.

## Installation

From a checkout:

```bash
chmod +x shieldctl
sudo ./shieldctl self-install
sudo shieldctl install
```

Install optional components:

```bash
sudo shieldctl install --firewall
sudo shieldctl install --usbguard
```

`install` may install Lynis, rkhunter, ClamAV, AIDE, fail2ban, auditd, and the
distribution-appropriate automatic-update package. Optional packages may require
additional distribution repositories.

## Safe first run

Always inspect the current state and preview changes first:

```bash
shieldctl status
sudo shieldctl harden --dry-run
```

When satisfied, apply the recommended baseline:

```bash
sudo shieldctl harden
sudo shieldctl status
```

For a disposable VM, snapshot the VM before testing. On a physical system, ensure
you have console access or a tested recovery route before changing firewall or
network settings.

## Command reference

### Status and reporting

```bash
shieldctl status
sudo shieldctl report
```

`status` is a dashboard, not a guarantee. It reports encryption, Secure Boot,
firewall state, AppArmor/SELinux, services, AIDE, kernel settings, listeners,
pending updates, reboot state, and recent runs.

Disk encryption is intentionally informational. shieldctl does **not** convert an
existing root disk because an incorrect conversion can destroy data or leave the
system unbootable. Choose LUKS or another supported encryption option during OS
installation, or use a distro-specific migration procedure with a verified backup.

### Hardening

```bash
sudo shieldctl harden
sudo shieldctl harden --dry-run
sudo shieldctl harden sysctl modules coredump perms firewall
sudo shieldctl harden umask
sudo shieldctl harden dns
sudo shieldctl harden usbguard
sudo shieldctl harden all
```

The default modules are:

| Module | Purpose |
|---|---|
| `sysctl` | Applies supported kernel and network hardening values |
| `modules` | Blocks selected obsolete or high-risk kernel modules |
| `coredump` | Restricts traditional and systemd core dumps |
| `perms` | Tightens selected permissions without making them looser |
| `firewall` | Enables/configures UFW or firewalld when available |

Opt-in modules:

| Module | Purpose |
|---|---|
| `umask` | Sets the login default umask to `027` |
| `dns` | Attempts DNS-over-TLS and reverts if resolution breaks |
| `usbguard` | Generates a USB policy and refuses unsafe replacement by default |

The `all` shortcut includes `umask` and `dns`, but does not enable USBGuard
automatically because USB policy mistakes can affect keyboards and other devices.

### Rollback

```bash
sudo shieldctl rollback
```

Rollback removes shieldctl-managed drop-ins and restores recorded file permissions,
backups, and service states. Runtime sysctl values remain active until reboot unless
changed separately. The firewall is deliberately left enabled; disable it manually
only after confirming an alternative firewall is active.

### Security scans

```bash
sudo shieldctl scan updates
sudo shieldctl scan ports
sudo shieldctl scan rootkit
sudo shieldctl scan malware
sudo shieldctl scan integrity
sudo shieldctl scan audit
sudo shieldctl scan all
```

Scan results are written under `/var/log/shieldctl` and summarized in the run history
under `/var/lib/shieldctl`. Malware scanning checks user Downloads when a desktop
user is discoverable, plus `/tmp` and `/var/tmp`; provide explicit paths when needed:

```bash
sudo shieldctl scan malware --path /home/alice/Downloads --path /srv/uploads
```

### AIDE integrity workflow

```bash
sudo shieldctl aide init
sudo shieldctl aide check
sudo shieldctl aide update --no-accept
sudo shieldctl aide accept
```

Recommended workflow:

1. Build a baseline after verifying the system is trusted.
2. Run `aide check`.
3. Review changes and the generated log.
4. Accept a new baseline only when every change is understood.

To run a long operation through systemd:

```bash
sudo shieldctl aide init --bg
journalctl -fu shieldctl-aide-init
```

### Services

```bash
shieldctl services list
sudo shieldctl services disable avahi-daemon
```

Only explicitly named services are changed. Each disable operation asks for
confirmation unless `--yes` is supplied and records the previous enabled state.

### Scheduling

Install the binary first so timers use a stable path:

```bash
sudo shieldctl schedule defaults
sudo shieldctl schedule add weekly-malware "scan malware" "Sun *-*-* 03:00"
shieldctl schedule list
sudo shieldctl schedule run weekly-malware
sudo shieldctl schedule remove weekly-malware
```

Allowed scheduled tasks are limited to:

```text
scan audit
scan rootkit
scan malware
scan integrity
scan updates
scan ports
scan all
status
```

`aide update` is intentionally not schedulable. Baseline changes require human
review and explicit acceptance.

### Self-management

```bash
sudo shieldctl self-install
sudo shieldctl self-uninstall
```

Uninstall removes the installed binary and shieldctl timers. Hardening files remain
until `sudo shieldctl rollback` is run.

## Global options

| Option | Meaning |
|---|---|
| `-n`, `--dry-run` | Preview changes without writing or applying them |
| `-y`, `--yes` | Answer safety confirmations positively |
| `-q`, `--quiet` | Suppress normal output; useful for timers |
| `--strict` | Try mandatory DNS-over-TLS before opportunistic mode |
| `--path DIR` | Add a malware-scan path; repeatable |
| `--bg` | Run an AIDE operation through systemd |
| `--no-accept` | Keep an AIDE update as a reviewable new database |
| `-h`, `--help` | Show command help |
| `-v`, `--version` | Print the version |

## Files and state

By default, shieldctl uses:

| Path | Contents |
|---|---|
| `/var/lib/shieldctl` | Manifest, backups, permissions, service state, run history |
| `/var/log/shieldctl` | Task logs |
| `/etc/sysctl.d/99-shieldctl.conf` | Managed kernel settings |
| `/etc/modprobe.d/shieldctl-blacklist.conf` | Managed module rules |
| `/etc/security/limits.d/99-shieldctl-nocore.conf` | Core-dump limit |
| `/etc/systemd/coredump.conf.d/shieldctl.conf` | systemd core-dump policy |
| `/etc/systemd/system/shieldctl-*.{service,timer}` | Scheduled task units |

For isolated testing, the state and configuration roots can be overridden:

```bash
SHIELDCTL_ETC="$PWD/test-etc" \
SHIELDCTL_STATE="$PWD/test-state" \
SHIELDCTL_LOG="$PWD/test-log" \
sudo -E ./shieldctl harden --dry-run
```

## Design and safety boundaries

- Unsupported kernel keys are skipped rather than persisted.
- `ip_forward`, `kernel.modules_disabled`, and `usb-storage` are deliberately
  untouched because they can break virtualization, containers, drivers, or input.
- Permissions are only tightened by the permission module.
- DNS changes are verified and reverted if resolution fails.
- USBGuard refuses to overwrite an existing policy unless explicitly authorized.
- Scheduled commands are allowlisted instead of accepting arbitrary shell code.
- Non-success scan results return non-zero and are recorded for systemd visibility.
- No cloud service, telemetry pipeline, or shieldctl network endpoint is required.

## Limitations

- Security tools can produce false positives and need administrator review.
- AIDE reports expected changes after package upgrades, configuration edits, and
  legitimate maintenance.
- Firewall rules can affect containers, virtual machines, discovery, and remote
  administration. Review local requirements first.
- Network listener detection reports exposure; it does not determine whether a
  service is safe.
- Automatic updates vary by distribution and may be unavailable or disabled by
  local policy.
- Root access is required for operations that inspect or modify protected resources.

## Development and validation

Basic syntax validation:

```bash
bash -n shieldctl
```

If installed, run ShellCheck before submitting changes:

```bash
shellcheck shieldctl
```

Test read-only behavior first:

```bash
./shieldctl --help
./shieldctl --version
./shieldctl status
./shieldctl services list
./shieldctl schedule list
```

## Contributing

Keep changes focused and conservative. Preserve the dry-run path, avoid destructive
defaults, quote shell expansions, return meaningful exit codes, and update this
README whenever commands, files, supported systems, or safety behavior change.

## License

shieldctl is released under the MIT License. See [LICENSE](./LICENSE).
