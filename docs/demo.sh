#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
TOOL="$ROOT/shieldctl"

if [ ! -x "$TOOL" ]; then
  printf 'shieldctl is not executable: %s\n' "$TOOL" >&2
  exit 1
fi

readonly C_BLUE=$'\033[1;38;5;117m'
readonly C_CYAN=$'\033[1;36m'
readonly C_GREEN=$'\033[1;32m'
readonly C_DIM=$'\033[2m'
readonly C_RESET=$'\033[0m'

pause() {
  sleep "${DEMO_PAUSE:-1}"
}

section() {
  printf '\n%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' \
    "$C_BLUE" "$C_RESET"
  printf '%s  %s%s\n' "$C_CYAN" "$1" "$C_RESET"
  printf '%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' \
    "$C_BLUE" "$C_RESET"
  pause
}

run_step() {
  printf '%s$%s %s\n' "$C_GREEN" "$C_RESET" "$*"
  "$@"
  pause
}

root_step() {
  if [ "$(id -u)" -eq 0 ]; then
    run_step "$@"
  else
    run_step sudo "$@"
  fi
}

printf '\033[2J\033[H'
printf '%s╔══════════════════════════════════════════════════════════════════════╗%s\n' \
  "$C_BLUE" "$C_RESET"
printf '%s║ %-68s ║%s\n' "$C_BLUE" "" "$C_RESET"
printf '%s║ %-68s ║%s\n' "$C_BLUE" "                           ShieldCTL" "$C_RESET"
printf '%s║ %-68s ║%s\n' "$C_BLUE" "" "$C_RESET"
printf '%s║ %-68s ║%s\n' "$C_BLUE" "                             0xmfbk" "$C_RESET"
printf '%s║ %-68s ║%s\n' "$C_BLUE" "" "$C_RESET"
printf '%s╚══════════════════════════════════════════════════════════════════════╝%s\n' \
  "$C_BLUE" "$C_RESET"
printf '%sThis demo is read-only except for isolated test temporary files.%s\n' \
  "$C_DIM" "$C_RESET"
pause

section "01  •  VERSION AND HELP"
run_step "$TOOL" --version
run_step "$TOOL" --help

section "02  •  READ-ONLY SYSTEM STATUS"
run_step "$TOOL" status

section "03  •  SAFE HARDENING PREVIEW"
printf '%sNo changes are applied. Firewall prompts are disabled in dry-run mode.%s\n' \
  "$C_DIM" "$C_RESET"
root_step "$TOOL" harden sysctl modules coredump --dry-run
root_step "$TOOL" harden firewall --dry-run --allow-port 22/tcp

section "04  •  FIREWALL REGRESSION PROTECTION"
run_step env ROOT="$ROOT" "$ROOT/tests/firewall_test.sh"

section "05  •  COMPLETE LOCAL TEST HARNESS"
if [ "$(id -u)" -eq 0 ] && command -v shellcheck >/dev/null 2>&1; then
  run_step env ROOT="$ROOT" "$ROOT/tests/run_all.sh"
elif command -v shellcheck >/dev/null 2>&1; then
  root_step env ROOT="$ROOT" "$ROOT/tests/run_all.sh"
else
  printf '%sRun the complete harness as root with ShellCheck for full CI parity.%s\n' \
    "$C_DIM" "$C_RESET"
  run_step bash -n "$TOOL" "$ROOT/tests/firewall_test.sh" \
    "$ROOT/tests/run_all.sh" "$ROOT/tests/run.sh"
  run_step env ROOT="$ROOT" "$ROOT/tests/firewall_test.sh"
fi

section "06  •  CONTAINER CI COMMANDS"
printf '%sRun these separately when Docker or Podman is available:%s\n' \
  "$C_DIM" "$C_RESET"
printf '  docker compose build debian && docker compose run --rm debian\n'
printf '  docker compose build fedora && docker compose run --rm fedora\n'

printf '\n%s✓ Demo complete — ShieldCTL is tested, reviewable, and reversible.%s\n' \
  "$C_GREEN" "$C_RESET"
