#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
TOOL="$ROOT/shieldctl"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export SHIELDCTL_ETC="$TMP/etc"
export SHIELDCTL_STATE="$TMP/state"
export SHIELDCTL_LOG="$TMP/log"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local text="$1" expected="$2"
  grep -Fq -- "$expected" <<<"$text" || fail "expected output to contain: $expected"
}

assert_not_contains() {
  local text="$1" unexpected="$2"
  ! grep -Fq -- "$unexpected" <<<"$text" || fail "unexpected output: $unexpected"
}

bash -n "$TOOL"
shellcheck "$TOOL"

version="$("$TOOL" --version)"
assert_contains "$version" "ShieldCTL"
assert_contains "$version" "shieldctl 1.0.1"

help="$("$TOOL" --help)"
assert_contains "$help" "harden [module...]"
assert_not_contains "$help" "DNS-over-TLS"
assert_not_contains "$help" --strict

dry_run="$("$TOOL" harden sysctl modules coredump --dry-run)"
assert_contains "$dry_run" "ShieldCTL"
assert_contains "$dry_run" "would write"
test "$(find "$TMP" -type f | wc -l)" -eq 0 || fail "dry-run created files"

"$TOOL" harden sysctl modules coredump >/dev/null
test -f "$SHIELDCTL_ETC/sysctl.d/99-shieldctl.conf" || fail "sysctl file missing"
test -f "$SHIELDCTL_ETC/modprobe.d/shieldctl-blacklist.conf" || fail "module file missing"
test -f "$SHIELDCTL_ETC/security/limits.d/99-shieldctl-nocore.conf" ||
  fail "limits file missing"
test -f "$SHIELDCTL_ETC/systemd/coredump.conf.d/shieldctl.conf" ||
  fail "coredump file missing"

"$TOOL" rollback >/dev/null
test ! -e "$SHIELDCTL_ETC/sysctl.d/99-shieldctl.conf" || fail "rollback left sysctl file"
test ! -e "$SHIELDCTL_ETC/modprobe.d/shieldctl-blacklist.conf" ||
  fail "rollback left module file"

if "$TOOL" harden dns >/dev/null 2>&1; then
  fail "removed dns module was accepted"
fi

"$TOOL" services list >/dev/null
"$TOOL" schedule list >/dev/null

printf 'PASS: ShieldCTL container checks completed (%s)\n' "${BASE_IMAGE:-unknown image}"
