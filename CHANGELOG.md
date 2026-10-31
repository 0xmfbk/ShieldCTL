# Changelog

Release assets for the latest version are available on the
[GitHub releases page](https://github.com/0xmfbk/ShieldCTL/releases).

## Unreleased

### Tests and documentation

- Added dedicated firewall regression coverage for SSH lockout prevention,
  explicit approvals, interface-scoped listeners, non-interactive runs,
  dry-run isolation, invalid ports, and empty arrays.
- Improved the manual demo flow with a polished title banner, shorter default
  pauses, full-speed mode through `DEMO_PAUSE=0`, and non-interactive sudo
  handling that skips unavailable root-only steps instead of hanging.
- Documented the complete local test command and the firewall regression scope.

## [1.0.1] - 2026-10-31

### Security

- Fixed a firewall hardening path that could insert a deny rule before existing
  allow rules and lock out a remote administrator. Firewall hardening now
  preserves the current SSH session, requires explicit approval for additional
  ports, and aborts safely when an unapproved SSH daemon is detected.

### Changed

- Require Bash 4.4 or newer and handle legitimately empty arrays safely.
- Require confirmation before background AIDE initialization rebuilds an existing
  baseline; background updates continue to require explicit review and acceptance.
- Report automatic-update state from the distribution's actual package, timer,
  and configuration state, with explicit opt-in for update-applying timers.

## [1.0.0] - First stable release

Initial stable release of ShieldCTL.
