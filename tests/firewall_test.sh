#!/usr/bin/env bash
set -u

ROOT="${ROOT:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
TOOL="$ROOT/shieldctl"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

failures=0

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s: %s\n' "$1" "$2" >&2
  failures=$((failures + 1))
}

setup_case() {
  local name="$1"
  CASE_DIR="$TMP/$name"
  mkdir -p "$CASE_DIR/bin"
  : >"$CASE_DIR/ufw.log"
  cat >"$CASE_DIR/bin/id" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = -u ]; then
  printf '0\n'
else
  /usr/bin/id "$@"
fi
EOF
  cat >"$CASE_DIR/bin/ss" <<'EOF'
#!/usr/bin/env bash
case "${FAKE_SS_MODE:-none}:$*" in
  remote:-H\ -tuln|remote:-H\ -tuln*)
    printf '%s\n' \
      'tcp LISTEN 0 128 0.0.0.0:22 0.0.0.0:*' \
      'udp UNCONN 0 0 0.0.0.0:5353 0.0.0.0:*' ;;
  sshd:-H\ -tuln|sshd:-H\ -tuln*)
    printf '%s\n' 'tcp LISTEN 0 128 0.0.0.0:22 0.0.0.0:*' ;;
  sshd:-H\ -tlnp|sshd:-H\ -tlnp*)
    printf '%s\n' 'tcp LISTEN 0 128 0.0.0.0:22 0.0.0.0:* users:(("sshd",pid=7,fd=3))' ;;
  interface:-H\ -tuln|interface:-H\ -tuln*)
    printf '%s\n' 'udp UNCONN 0 0 0.0.0.0%virbr0:67 0.0.0.0:*' ;;
  none:*) ;;
esac
EOF
  cat >"$CASE_DIR/bin/ufw" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_LOG"
EOF
  cat >"$CASE_DIR/bin/firewall-cmd" <<'EOF'
#!/usr/bin/env bash
printf 'firewall-cmd %s\n' "$*" >>"$FAKE_LOG"
EOF
  cat >"$CASE_DIR/bin/timeshift" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod 755 "$CASE_DIR/bin/"*
  export CASE_DIR
  export FAKE_LOG="$CASE_DIR/ufw.log"
  export PATH="$CASE_DIR/bin:$PATH"
  export SHIELDCTL_ETC=/etc
  export SHIELDCTL_STATE="$CASE_DIR/state"
  export SHIELDCTL_LOG="$CASE_DIR/log"
  export SSH_CONNECTION=
  export SSH_CLIENT=
}

run_tool() {
  "$TOOL" "$@"
}

has_log() {
  grep -Fq -- "$1" "$FAKE_LOG"
}

not_log() {
  ! grep -Fq -- "$1" "$FAKE_LOG"
}

test_remote_admin() {
  local name="remote admin preserves SSH"
  setup_case remote
  export FAKE_SS_MODE=remote
  export SSH_CONNECTION='1.2.3.4 5555 10.0.0.5 22'
  if run_tool harden firewall --yes >/dev/null 2>&1 &&
    has_log 'allow 22/tcp' &&
    has_log 'default deny incoming' &&
    has_log '--force enable' &&
    not_log 'deny 22' &&
    not_log 'insert'; then
    pass "$name"
  else
    fail "$name" "unsafe or missing UFW calls"
  fi
}

test_sshd_requires_approval() {
  local name="unapproved SSH daemon aborts"
  setup_case sshd
  export FAKE_SS_MODE=sshd
  if run_tool harden firewall --yes >/dev/null 2>&1; then
    fail "$name" "command unexpectedly succeeded"
  elif has_log enable; then
    fail "$name" "firewall was enabled"
  else
    pass "$name"
  fi
}

test_allow_port_ssh() {
  local name="explicit SSH allow-port succeeds"
  setup_case sshd-approved
  export FAKE_SS_MODE=sshd
  if run_tool harden firewall --yes --allow-port 22/tcp >/dev/null 2>&1 &&
    has_log 'allow 22/tcp' && has_log enable; then
    pass "$name"
  else
    fail "$name" "explicit SSH port was not allowed safely"
  fi
}

test_interface_scope() {
  local name="interface-scoped listener keeps interface scope" old_path script_bin status
  setup_case interface
  export FAKE_SS_MODE=interface
  script_bin="$(command -v script || true)"
  old_path="$PATH"
  for command in bash readlink mkdir chmod awk sort grep cat sed; do
    ln -s "$(command -v "$command")" "$CASE_DIR/bin/$command"
  done
  export PATH="$CASE_DIR/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/bin"
  cat >"$CASE_DIR/run.sh" <<EOF
#!/usr/bin/env bash
exec "$TOOL" harden firewall
EOF
  chmod 755 "$CASE_DIR/run.sh"
  if command -v expect >/dev/null 2>&1; then
    EXPECT_RUN="$CASE_DIR/run.sh" expect <<'EOF' >"$CASE_DIR/pty.out" 2>&1
set timeout 30
spawn bash $env(EXPECT_RUN)
expect "Create a Timeshift snapshot first?"
send "Y\r"
expect "Allow incoming udp/67 on virbr0 from anywhere?"
send "Y\r"
expect eof
EOF
  elif [ -n "$script_bin" ]; then
    printf 'Y\nY\n' | "$script_bin" -qec "bash '$CASE_DIR/run.sh'" /dev/null >"$CASE_DIR/pty.out" 2>&1
  else
    fail "$name" "expect or script command is required for the interactive test"
    return
  fi
  status=$?
  if [ "$status" -ne 0 ]; then
    local output
    output="$(cat "$CASE_DIR/pty.out" 2>/dev/null || true)"
    export PATH="$old_path"
    fail "$name" "pseudo-terminal approval failed: $output"
    return
  fi
  export PATH="$old_path"
  if has_log 'allow in on virbr0' && not_log 'allow 67/udp'; then
    pass "$name"
  else
    fail "$name" "listener was not restricted to virbr0 (output: $(tr '\n' ' ' <"$CASE_DIR/pty.out"); log: $(tr '\n' ' ' <"$FAKE_LOG"))"
  fi
}

test_noninteractive_closed() {
  local name="noninteractive mode stays closed"
  setup_case remote-noninteractive
  export FAKE_SS_MODE=remote
  export SSH_CONNECTION='1.2.3.4 5555 10.0.0.5 22'
  if run_tool harden firewall >/dev/null 2>&1 &&
    has_log 'allow 22/tcp' &&
    not_log 'allow 5353/udp'; then
    pass "$name"
  else
    fail "$name" "noninteractive mode opened an unapproved port"
  fi
}

test_dry_run() {
  local name="dry-run does not call UFW"
  setup_case dry-run
  export FAKE_SS_MODE=none
  if run_tool harden firewall --dry-run >/dev/null 2>&1 &&
    [ ! -s "$FAKE_LOG" ]; then
    pass "$name"
  else
    fail "$name" "dry-run called the firewall backend"
  fi
}

test_invalid_ports() {
  local name="invalid allow-port values are rejected"
  local value
  setup_case invalid
  for value in 0/tcp 70000/tcp 22/icmp '22; reboot'; do
    if run_tool harden firewall --allow-port "$value" >/dev/null 2>&1 ||
      [ -s "$FAKE_LOG" ]; then
      fail "$name" "accepted or executed for $value"
      return
    fi
  done
  pass "$name"
}

test_empty_arrays() {
  local name="empty arrays stay safe under set-u"
  setup_case empty
  export FAKE_SS_MODE=none
  if run_tool status >/dev/null 2>&1 &&
    run_tool services list >/dev/null 2>&1 &&
    run_tool schedule list >/dev/null 2>&1 &&
    run_tool scan ports >/dev/null 2>&1 &&
    run_tool harden firewall --dry-run >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "read-only command failed with empty arrays"
  fi
}

test_remote_admin
test_sshd_requires_approval
test_allow_port_ssh
test_interface_scope
test_noninteractive_closed
test_dry_run
test_invalid_ports
test_empty_arrays

if [ "$failures" -gt 0 ]; then
  printf 'FAIL: %d firewall test(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'PASS: firewall test suite completed\n'
