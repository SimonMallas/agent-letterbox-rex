#!/usr/bin/env bash
# Rex doorbell: fake rex only. No live server, no real mailbox.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
lb="$root/bin/letterbox"
adapter="$root/adapters/rex.sh"
work="$(mktemp -d "${TMPDIR:-/tmp}/lb-rex.XXXXXX")"
trap 'rm -rf "$work"' EXIT

block='block:01234567-89ab-cdef-0123-456789abcdef'
log="$work/rex.log"
cat > "$work/rex" << 'EOF'
#!/bin/bash
log="${REX_LOG:?}"
{
  printf 'CALL'
  for a in "$@"; do printf '\t%s' "$a"; done
  printf '\n'
} >> "$log"
word() {
  local want="$1" a
  shift
  for a in "$@"; do
    [[ "$a" == "$want" ]] && return 0
  done
  return 1
}
word skill "$@" && exit 9
if word inspect "$@"; then
  case "${REX_FAKE_INSPECT:-0}" in
    sleep) sleep 5; exit 0;;
    3) exit 3;;
    4) exit 4;;
    *) exit 0;;
  esac
fi
if word program_status "$@"; then
  case "${REX_FAKE_STATUS:-clear}" in
    blocked) printf '%s\n' '{"records":[{"state":"blocked"}]}'; exit 0;;
    fail) exit 1;;
    *) printf '%s\n' '{"records":[]}'; exit 0;;
  esac
fi
if word process "$@"; then
  case "${REX_FAKE_FRONT:-cat}" in
    fail) exit 1;;
    *) printf '{"foreground":{"name":"%s"}}\n' "${REX_FAKE_FRONT:-cat}"; exit 0;;
  esac
fi
if word send-key "$@"; then
  exit "${REX_FAKE_ENTER:-0}"
fi
if word send "$@"; then
  exit "${REX_FAKE_SEND:-0}"
fi
if word version "$@"; then
  printf 'rex 0.0.0-test\n'
  exit 0
fi
exit 0
EOF
chmod +x "$work/rex" "$adapter"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
ok() { printf 'ok: %s\n' "$1"; }

reset_log() { : > "$log"; }

assert_autostart() {
  [[ -s "$log" ]] || return 0
  grep -q $'\t--autostart=false\t' "$log" || fail "missing --autostart=false"
  if grep -q $'\tskill\t' "$log"; then fail "skill was invoked"; fi
}

ring() {
  env -u REX_BIN_DIR \
    LETTERBOX_DIR="$work/box" \
    LETTERBOX_REX_REGISTRY="$work/box/rex-agents.tsv" \
    LETTERBOX_DOORBELL_ENTER_DELAY="${LETTERBOX_DOORBELL_ENTER_DELAY:-0}" \
    LETTERBOX_DOORBELL_TIMEOUT="${LETTERBOX_DOORBELL_TIMEOUT:-1}" \
    REX_BIN_PATH="$work/rex" \
    REX_LOG="$log" \
    REX_FAKE_INSPECT="${REX_FAKE_INSPECT:-0}" \
    REX_FAKE_STATUS="${REX_FAKE_STATUS:-clear}" \
    REX_FAKE_FRONT="${REX_FAKE_FRONT:-cat}" \
    REX_FAKE_SEND="${REX_FAKE_SEND:-0}" \
    REX_FAKE_ENTER="${REX_FAKE_ENTER:-0}" \
    LETTERBOX_REX_SUBMIT="${LETTERBOX_REX_SUBMIT:-1}" \
    "$adapter" "$@"
}

mkdir -p "$work/box" "$work/home"
printf 'alpha\t%s\t\t2026-11-20T00:00:00Z\n' "$block" > "$work/box/rex-agents.tsv"

# Help, and register refuses anything that is not a full block id.
out="$(env -u LETTERBOX_AGENT -u LETTERBOX_DIR "$lb" rex --help)"
[[ "$out" == 'usage: letterbox rex '* ]] || fail "rex help: $out"
if env HOME="$work/home" LETTERBOX_DIR="$work/box" REX_BIN_PATH="$work/rex" REX_LOG="$log" \
    "$lb" rex register alpha --block shy-creek >/dev/null 2>"$work/err"; then
  fail "short label was accepted"
fi
grep -q 'full block id' "$work/err" || fail "label refusal"
if env HOME="$work/home" LETTERBOX_DIR="$work/box" REX_BIN_PATH="$work/rex" REX_LOG="$log" \
    "$lb" rex register alpha --block 'block:abcd' >/dev/null 2>"$work/err"; then
  fail "short id was accepted"
fi
ok "register refuses a label and a short id"

reset_log
env HOME="$work/home" LETTERBOX_DIR="$work/box" REX_BIN_PATH="$work/rex" REX_LOG="$log" \
  REX_FAKE_INSPECT=0 "$lb" rex register alpha --block "$block" >"$work/reg.out"
grep -q '^registered: alpha$' "$work/reg.out" || fail "register did not confirm"
grep -q "$block" "$work/box/rex-agents.tsv" || fail "registry missed the id"
assert_autostart
[[ ! -e "$work/home/.agent-letterbox" ]] || fail "register touched the default box"
ok "register stores the full id"

env HOME="$work/home" LETTERBOX_DIR="$work/regbox" \
  "$lb" rex setup --agents alpha,beta --dir "$work/regbox" >"$work/setup.out"
grep -q '^rex team ready$' "$work/setup.out" || fail "setup"
grep -q 'adapters/rex.sh' "$work/regbox/env.sh" || fail "setup doorbell"
[[ ! -e "$work/home/.agent-letterbox" && ! -e "$work/home/.local" && ! -e "$work/home/.agents" ]] \
  || fail "setup installed something"
ok "setup writes the box only"

reset_log
out="$(ring alpha info probe)"
[[ "$out" == 'doorbell-outcome v=1 outcome=submitted reason=- target='"$block" ]] || fail "submit: $out"
assert_autostart
grep -q $'\tsend\t' "$log" || fail "send missing"
grep -q $'\tsend-key\t' "$log" || fail "enter missing"
# send comes before send-key
send_line="$(grep -n $'\tsend\t' "$log" | head -1 | cut -d: -f1)"
key_line="$(grep -n $'\tsend-key\t' "$log" | head -1 | cut -d: -f1)"
[[ "$send_line" -lt "$key_line" ]] || fail "enter ran before the text"
grep -q "$block" "$log" || fail "full id not passed"
grep -q $'\tshy-creek\t' "$log" && fail "a session label was passed"
ok "ring sends the line, then enter, by full id"

reset_log
REX_FAKE_INSPECT=3
out="$(ring alpha info probe)"
[[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=surface_not_found target=-' ]] || fail "missing: $out"
grep -q $'\tsend\t' "$log" && fail "send ran for a missing block"
ok "exit 3 is surface_not_found and does not type"

reset_log
REX_FAKE_INSPECT=4
out="$(ring alpha info probe)"
[[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=server_unreachable target=-' ]] || fail "down: $out"
grep -q $'\tsend\t' "$log" && fail "send ran with no server"
ok "exit 4 is server_unreachable and is not a retryable timeout"

reset_log
REX_FAKE_INSPECT=sleep
out="$(ring alpha info probe)"
[[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=helper_timeout target=-' ]] || fail "timeout: $out"
grep -q $'\tsend\t' "$log" && fail "send ran after a lookup timeout"
ok "a lookup timeout is helper_timeout, before any text"

reset_log
REX_FAKE_INSPECT=0
REX_FAKE_FRONT=zsh
out="$(ring alpha info probe)"
[[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=shell_foreground target=-' ]] || fail "shell: $out"
grep -q $'\tsend\t' "$log" && fail "send ran into a shell"
ok "a shell in front is not typed into"

reset_log
REX_FAKE_FRONT=cat
REX_FAKE_STATUS=blocked
out="$(ring alpha info probe)"
[[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=agent_blocked target=-' ]] || fail "blocked: $out"
grep -q $'\tsend\t' "$log" && fail "send ran while blocked"
ok "a blocked program is not typed into"

reset_log
REX_FAKE_STATUS=clear
REX_FAKE_SEND=1
out="$(ring alpha info probe)"
[[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=send_failed target=-' ]] || fail "send fail: $out"
ok "a failed send is send_failed"

reset_log
REX_FAKE_SEND=0
REX_FAKE_ENTER=1
out="$(ring alpha info probe)"
[[ "$out" == 'doorbell-outcome v=1 outcome=pasted_not_submitted reason=enter_failed target='"$block" ]] || fail "enter: $out"
ok "text without enter is pasted_not_submitted"

reset_log
REX_FAKE_ENTER=0
LETTERBOX_REX_SUBMIT=0
out="$(ring alpha info probe)"
[[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=notify_only target=-' ]] || fail "quiet: $out"
grep -q $'\tsend\t' "$log" && fail "send ran when submit is off"
grep -q $'\tsend-key\t' "$log" && fail "enter ran when submit is off"
ok "submit off does not type"

unset LETTERBOX_REX_SUBMIT
printf 'alpha\tshy-creek\t\t2026-11-20T00:00:00Z\n' > "$work/box/rex-agents.tsv"
reset_log
out="$(ring alpha info probe)"
[[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=surface_not_found target=-' ]] || fail "label row: $out"
[[ ! -s "$log" ]] || fail "a label was sent to rex"
ok "a label in the registry is not passed to rex"

out="$(env REX_BIN_PATH="$work/no-such-rex" LETTERBOX_DIR="$work/box" "$adapter" alpha info probe 2>/dev/null || true)"
[[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-' ]] || fail "missing bin: $out"
ok "a missing rex is adapter_unavailable"

mkdir -p "$work/decoy" "$work/bindir" "$work/boxdir"
cp "$work/rex" "$work/bindir/rex"
cat > "$work/decoy/rex" << EOF
#!/usr/bin/perl
open(F, ">>$work/decoy-ran");
print F "ran\\n";
close(F);
EOF
chmod +x "$work/decoy/rex"

printf 'alpha\t%s\t\t2026-11-20T00:00:00Z\n' "$block" > "$work/box/rex-agents.tsv"
reset_log
out="$(env -u REX_BIN_PATH \
  HOME="$work/home" \
  PATH="$work/decoy:/usr/bin:/bin" \
  REX_BIN_DIR="$work/bindir" \
  REX_LOG="$log" \
  LETTERBOX_DIR="$work/box" \
  LETTERBOX_REX_REGISTRY="$work/box/rex-agents.tsv" \
  LETTERBOX_DOORBELL_ENTER_DELAY=0 \
  LETTERBOX_DOORBELL_TIMEOUT=1 \
  "$adapter" alpha info probe)"
[[ "$out" == 'doorbell-outcome v=1 outcome=submitted reason=- target='"$block" ]] || fail "dir: $out"
grep -q $'\tversion$' "$log" || fail "version was not checked"
[[ ! -e "$work/decoy-ran" ]] || fail "the other rex was executed"
ok "REX_BIN_DIR is used and a different rex on PATH is not run"

reset_log
out="$(env -u REX_BIN_PATH -u REX_BIN_DIR \
  HOME="$work/home" \
  PATH="$work/decoy:/usr/bin:/bin" \
  LETTERBOX_DIR="$work/box" \
  "$adapter" alpha info probe 2>/dev/null || true)"
[[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-' ]] || fail "decoy path: $out"
[[ ! -e "$work/decoy-ran" ]] || fail "a PATH rex was executed"
ok "a Perl script on PATH is refused and is not run"

mkdir -p "$work/other"
cat > "$work/other/rex" << EOF
#!/bin/sh
printf 'ran\\n' >> "$work/other-ran"
printf 'not rex\\n'
EOF
chmod +x "$work/other/rex"
out="$(env -u REX_BIN_PATH -u REX_BIN_DIR \
  HOME="$work/home" \
  PATH="$work/other:/usr/bin:/bin" \
  LETTERBOX_DIR="$work/box" \
  "$adapter" alpha info probe 2>/dev/null || true)"
[[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-' ]] || fail "other path: $out"
runs="$(grep -c . "$work/other-ran" || true)"
[[ "$runs" == "1" ]] || fail "version ran the other rex $runs times"
ok "a different rex on PATH is run once for version and then refused"

reset_log
env -u REX_BIN_PATH \
  HOME="$work/home" \
  PATH="$work/decoy:/usr/bin:/bin" \
  REX_BIN_DIR="$work/bindir" \
  REX_LOG="$log" \
  LETTERBOX_DIR="$work/boxdir" \
  "$lb" rex register gamma --block "$block" >"$work/regdir.out"
grep -q '^registered: gamma$' "$work/regdir.out" || fail "register via REX_BIN_DIR: $(cat "$work/regdir.out")"
grep -q $'\tversion$' "$log" || fail "register skipped the version check"
[[ ! -e "$work/decoy-ran" ]] || fail "register executed the other rex"
ok "register uses REX_BIN_DIR"

printf 'rex adapter: PASS\n'
