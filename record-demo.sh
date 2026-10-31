#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SHIELDCTL="$SCRIPT_DIR/shieldctl"

if [ ! -x "$SHIELDCTL" ]; then
  printf '\033[1;31mError:\033[0m %s is missing or not executable.\n' "$SHIELDCTL" >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  printf '\033[1;31mError:\033[0m sudo is required for this recording.\n' >&2
  exit 1
fi

if ! sudo -v; then
  printf '\033[1;31mError:\033[0m sudo authentication failed.\n' >&2
  exit 1
fi

readonly RESET='\033[0m'
readonly DIM='\033[2m'
readonly BOLD='\033[1m'
readonly CYAN='\033[1;36m'
readonly BLUE='\033[1;34m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly BOX_WIDTH=99

box_line() {
  local text="$1" style="$2" left right
  left=$(( (BOX_WIDTH - ${#text}) / 2 ))
  right=$(( BOX_WIDTH - ${#text} - left ))
  printf '%b║%*s%b%s%b%*s║%b\n' \
    "$CYAN" "$left" '' "$style" "$text" "$RESET" "$right" '' "$RESET"
}

rule() {
  printf '%b\n' "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

title() {
  local border
  printf -v border '%*s' "$BOX_WIDTH" ''
  border=${border// /═}
  clear
  printf '\n'
  printf '%b╔%s╗%b\n' "$CYAN" "$border" "$RESET"
  box_line 'ShieldCTL' "$BOLD"
  box_line 'by 0xmfbk  •  Linux security hardening toolkit' "$DIM"
  printf '%b╚%s╝%b\n' "$CYAN" "$border" "$RESET"
  printf '\n'
}

section() {
  printf '\n%b\n' "${YELLOW}▸ $1${RESET}"
  rule
}

run_shieldctl() {
  local description="$1"
  shift
  printf '\n%b %s\n' "${GREEN}▶${RESET}" "$description"
  printf '%b$ sudo shieldctl %s%b\n\n' "$DIM" "$*" "$RESET"
  sudo "$SHIELDCTL" "$@"
  sleep 2
}

title
printf '%b\n' "${DIM}This recording applies no hardening changes.${RESET}"
printf '%b\n' "${DIM}All ShieldCTL commands run with sudo for complete system visibility.${RESET}"
sleep 3

section "Version and capabilities"
run_shieldctl "Show the installed ShieldCTL version" --version
run_shieldctl "Show available commands and safety options" --help

section "Current security posture"
run_shieldctl "Display protection layers, kernel hardening, and exposure" status

section "Safe hardening preview"
run_shieldctl "Preview the default hardening plan without changing the system" --dry-run harden

section "Network and activity visibility"
run_shieldctl "Inspect exposed network listeners" scan ports
run_shieldctl "Display recent scheduled and manual results" report

printf '\n'
rule
printf '%b\n' "${GREEN}✓ Demonstration complete${RESET}"
printf '%b\n' "${DIM}No hardening changes were applied. Review the output before using shieldctl harden.${RESET}"
printf '\n'
