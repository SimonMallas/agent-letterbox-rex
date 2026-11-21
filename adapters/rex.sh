#!/usr/bin/env bash
# Rex doorbell adapter. The letter is already durable. This rings one Rex
# block and prints one doorbell-outcome line. The wrapper owns forwarding.
#
# Registry (LETTERBOX_REX_REGISTRY, else $LETTERBOX_DIR/rex-agents.tsv):
#   agent<TAB>block_id<TAB>session<TAB>registered_at
# Optional fallback (LETTERBOX_REX_PATTERNS):
#   agent<TAB>block_id
# A block id is the full form only: block: and a UUID. A label or a short
# id is ignored, because Rex can match those to the wrong block.
#
# Every Rex command is --autostart=false. This adapter does not start a server.
# Text is rex send. Enter is a later rex send-key, after the usual pause.
# Binary: REX_BIN_PATH if set (that name is ours). Otherwise REX_BIN_DIR,
# which Rex sets, then the Mac app bundle, then a PATH rex only when
# `rex version` says it is this Rex. That ask runs the PATH program once.
# A Perl script of the same name is not executed.
#
# Arguments: recipient message-type slug [doorbell-token]
#        or: --shell-guard recipient
set -uo pipefail

probe=false
if [[ "${1:-}" == --shell-guard ]]; then
  probe=true
  set -- "${2:?recipient}" probe probe
fi

to="${1:?recipient}"
type="${2:?type}"
slug="${3:?slug}"
token="${4:-}"

emit_outcome() { # $1=outcome $2=reason $3=target
  local outcome="$1" reason="$2" target="$3"
  case "$outcome" in
    submitted)
      [[ "$reason" == "-" && "$target" != "-" ]] || return 1
      [[ "$target" =~ ^[A-Za-z0-9._:+-]+$ || "$target" =~ ^%[0-9]+$ ]] || return 1
      ;;
    pasted_not_submitted)
      case "$reason" in enter_failed|-) ;; *) return 1;; esac
      [[ "$target" != "-" ]] || return 1
      [[ "$target" =~ ^[A-Za-z0-9._:+-]+$ || "$target" =~ ^%[0-9]+$ ]] || return 1
      ;;
    no_live_surface)
      [[ "$reason" != "-" && "$reason" =~ ^[A-Za-z0-9._:+-]+$ ]] || return 1
      [[ "$target" == "-" ]] || return 1
      ;;
    *) return 1;;
  esac
  printf 'doorbell-outcome v=1 outcome=%s reason=%s target=%s\n' \
    "$outcome" "$reason" "$target"
}

bounded_cmd() { # $1=seconds, rest=argv
  local secs="$1"; shift
  command -v python3 >/dev/null 2>&1 || return 125
  python3 -c '
import os, signal, subprocess, sys
secs = float(sys.argv[1])
try:
    p = subprocess.Popen(sys.argv[2:], start_new_session=True)
except FileNotFoundError:
    sys.exit(127)
try:
    rc = p.wait(timeout=secs)
except subprocess.TimeoutExpired:
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except Exception:
        p.kill()
    p.wait()
    sys.exit(124)
sys.exit(123 if rc == 124 else rc)
' "$secs" "$@"
}

# 0 when $1 is executable, is not a Perl script, and its version line is "rex" plus a digit.
rex_version_ok() {
  local bin="$1" head first out ec
  [[ -n "$bin" && -x "$bin" ]] || return 1
  # Drop NUL bytes before the substitution. A compiled rex has them in the
  # header, and bash 5 warns if a command substitution contains one.
  # C locale keeps macOS tr from warning on the header's other bytes.
  # The Perl shebang has no NUL, so the guard still sees it.
  head="$(LC_ALL=C head -c 80 "$bin" 2>/dev/null | LC_ALL=C tr -d '\000' || true)"
  case "$head" in
    "#!"*perl*) return 1;;
  esac
  ec=0
  out="$(bounded_cmd 5 "$bin" --autostart=false --timeout 5s --color never version 2>/dev/null)" || ec=$?
  [[ "$ec" -eq 0 ]] || return 1
  first="${out%%$'\n'*}"
  [[ "$first" == rex\ [0-9]* ]]
}

resolve_rex() {
  local mac found
  if [[ -n "${REX_BIN_PATH:-}" ]]; then
    printf '%s\n' "$REX_BIN_PATH"
    return 0
  fi
  if [[ -n "${REX_BIN_DIR:-}" ]] && rex_version_ok "${REX_BIN_DIR}/rex"; then
    printf '%s\n' "${REX_BIN_DIR}/rex"
    return 0
  fi
  mac="${HOME}/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
  if rex_version_ok "$mac"; then
    printf '%s\n' "$mac"
    return 0
  fi
  found="$(command -v rex 2>/dev/null || true)"
  if [[ -n "$found" ]] && rex_version_ok "$found"; then
    printf '%s\n' "$found"
    return 0
  fi
  return 1
}

rex_bin="$(resolve_rex)" || { emit_outcome no_live_surface adapter_unavailable -; exit 0; }
if [[ "$rex_bin" == */* ]]; then
  [[ -x "$rex_bin" ]] || { emit_outcome no_live_surface adapter_unavailable -; exit 0; }
else
  command -v "$rex_bin" >/dev/null 2>&1 || { emit_outcome no_live_surface adapter_unavailable -; exit 0; }
fi
command -v python3 >/dev/null 2>&1 || { emit_outcome no_live_surface adapter_unavailable -; exit 0; }

enter_delay="${LETTERBOX_DOORBELL_ENTER_DELAY:-2}"
[[ "$enter_delay" =~ ^[0-5]$ ]] || { emit_outcome no_live_surface invalid_enter_delay -; exit 0; }
bound_s="${LETTERBOX_DOORBELL_TIMEOUT:-1}"
[[ "$bound_s" =~ ^[1-9][0-9]{0,2}$ ]] || { emit_outcome no_live_surface invalid_timeout -; exit 0; }

line_from="${LETTERBOX_DOORBELL_FROM:-}"
if [[ "$line_from" =~ ^[A-Za-z][A-Za-z0-9._-]{0,31}$ ]]; then
  line="📬 letterbox doorbell: unacked $type from $line_from in ${LETTERBOX_DIR:?set LETTERBOX_DIR}/$to/inbox/ — please check"
else
  line="📬 letterbox doorbell: unacked $type in ${LETTERBOX_DIR:?set LETTERBOX_DIR}/$to/inbox/ — please check"
fi
[[ "$token" =~ ^[0-9a-f]{8}$ ]] && line="$line · $token"

# Full block id only. Labels and short suffixes can hit the wrong block.
rex_full_id() {
  [[ "$1" =~ ^block:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

run_rex() {
  bounded_cmd "$bound_s" "$rex_bin" --autostart=false --timeout "${bound_s}s" --color never "$@"
}

# Prints the foreground program name, or nothing. Status 124 on timeout.
front_name() {
  local out ec=0
  out="$(run_rex block call -b "$1" process 2>/dev/null)" || ec=$?
  [[ "$ec" -eq 124 ]] && return 124
  [[ "$ec" -eq 0 ]] || return 0
  printf '%s' "$out" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
except Exception:
    raise SystemExit
name = ((d.get("foreground") or {}).get("name") or "")
if isinstance(name, str):
    sys.stdout.write(name)
'
}

# 0 = a record says blocked, 1 = not blocked, 124 = timed out.
status_blocked() {
  local out ec=0
  out="$(run_rex block call -b "$1" program_status 2>/dev/null)" || ec=$?
  [[ "$ec" -eq 124 ]] && return 124
  [[ "$ec" -eq 0 ]] || return 1
  [[ "$(printf '%s' "$out" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
except Exception:
    raise SystemExit
recs = d.get("records") or []
sys.stdout.write("yes" if any((r or {}).get("state") == "blocked" for r in recs) else "no")
')" == yes ]]
}

is_shell() {
  case "$1" in
    zsh|bash|sh|fish|dash|ksh|tcsh) return 0;;
    *) return 1;;
  esac
}

block_id=''

# 0 = this id is live and was stored. Exits on a timeout or a dead server.
take_live() {
  local id="$1" ec=0
  rex_full_id "$id" || return 1
  run_rex block inspect "$id" --json >/dev/null 2>&1 || ec=$?
  if [[ "$ec" -eq 124 ]]; then
    emit_outcome no_live_surface helper_timeout -
    exit 0
  fi
  if [[ "$ec" -eq 4 ]]; then
    emit_outcome no_live_surface server_unreachable -
    exit 0
  fi
  if [[ "$ec" -eq 0 ]]; then
    block_id="$id"
    return 0
  fi
  return 1
}

registry_file="${LETTERBOX_REX_REGISTRY:-}"
if [[ -z "$registry_file" && -n "${LETTERBOX_DIR:-}" ]]; then
  registry_file="$LETTERBOX_DIR/rex-agents.tsv"
fi
if [[ -n "$registry_file" && -r "$registry_file" ]]; then
  while IFS=$'\t' read -r agent pane _session _ts || [[ -n "${agent:-}" ]]; do
    [[ "$agent" == \#* || -z "${agent:-}" ]] && continue
    [[ "$agent" == "$to" && -n "${pane:-}" ]] || continue
    take_live "$pane" && break
  done < "$registry_file"
fi

if [[ -z "$block_id" ]]; then
  patterns_file="${LETTERBOX_REX_PATTERNS:-}"
  if [[ -z "$patterns_file" && -n "${LETTERBOX_DIR:-}" ]]; then
    patterns_file="$LETTERBOX_DIR/rex-patterns.tsv"
  fi
  if [[ -n "$patterns_file" && -r "$patterns_file" ]]; then
    while IFS=$'\t' read -r agent pane || [[ -n "${agent:-}" ]]; do
      [[ "$agent" == \#* || -z "${agent:-}" ]] && continue
      [[ "$agent" == "$to" && -n "${pane:-}" ]] || continue
      take_live "$pane" && break
    done < "$patterns_file"
  fi
fi

[[ -n "$block_id" ]] || { emit_outcome no_live_surface surface_not_found -; exit 0; }

if [[ "$probe" == true ]]; then
  [[ "${LETTERBOX_REX_SUBMIT:-1}" != 0 ]] || exit 0
  name=""
  name_ec=0
  name="$(front_name "$block_id")" || name_ec=$?
  if [[ "$name_ec" -eq 0 && -n "$name" ]]; then
    printf 'shell-guard: available\n'
  else
    printf 'shell-guard: unavailable (the block foreground could not be read; doorbells are typed without that check)\n'
  fi
  exit 0
fi

if [[ "${LETTERBOX_REX_SUBMIT:-1}" == 0 ]]; then
  emit_outcome no_live_surface notify_only -
  exit 0
fi

name=""
name_ec=0
name="$(front_name "$block_id")" || name_ec=$?
if [[ "$name_ec" -eq 124 ]]; then
  emit_outcome no_live_surface helper_timeout -
  exit 0
fi
if is_shell "$name"; then
  emit_outcome no_live_surface shell_foreground -
  exit 0
fi

st_ec=0
status_blocked "$block_id" || st_ec=$?
if [[ "$st_ec" -eq 124 ]]; then
  emit_outcome no_live_surface helper_timeout -
  exit 0
fi
if [[ "$st_ec" -eq 0 ]]; then
  emit_outcome no_live_surface agent_blocked -
  exit 0
fi

send_ec=0
run_rex send -b "$block_id" "$line" >/dev/null 2>&1 || send_ec=$?
if [[ "$send_ec" -ne 0 ]]; then
  if [[ "$send_ec" -eq 124 ]]; then
    emit_outcome no_live_surface unconfirmed -
  else
    emit_outcome no_live_surface send_failed -
  fi
  exit 0
fi

sleep "$enter_delay"

name="$(front_name "$block_id" 2>/dev/null || true)"
if is_shell "$name"; then
  emit_outcome pasted_not_submitted - "$block_id"
  exit 0
fi

enter_ec=0
run_rex send-key -b "$block_id" enter >/dev/null 2>&1 || enter_ec=$?
if [[ "$enter_ec" -ne 0 ]]; then
  if [[ "$enter_ec" -eq 124 ]]; then
    emit_outcome no_live_surface unconfirmed -
  else
    emit_outcome pasted_not_submitted enter_failed "$block_id"
  fi
  exit 0
fi
emit_outcome submitted - "$block_id"
