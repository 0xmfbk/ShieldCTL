#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"

bash -n "$ROOT/shieldctl" "$ROOT/tests/firewall_test.sh" "$ROOT/tests/run.sh"
shellcheck -S warning "$ROOT/shieldctl" "$ROOT/tests/firewall_test.sh" "$ROOT/tests/run.sh"
"$ROOT/tests/run.sh"
"$ROOT/tests/firewall_test.sh"
