# Changelog

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
