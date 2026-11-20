#!/usr/bin/env bash
# The installer is both the first install and the update. An update must say it
# updated and must not print the first-time team setup: that setup is shared,
# and an agent updating itself had to work out not to run it (26 Oct).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
if ! git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '%s\n' 'install update suite: SKIP (not a git checkout)'
  exit 0
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME"
# The update's git pull would start git's background maintenance, which keeps
# writing under $tmp/install/.git while the trap above deletes it.
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=maintenance.auto GIT_CONFIG_VALUE_0=false
git clone -q "$root" "$tmp/source"
export AGENT_LETTERBOX_REPO="$tmp/source"
export AGENT_LETTERBOX_INSTALL_DIR="$tmp/install"
export AGENT_LETTERBOX_BIN_DIR="$tmp/bin"

first="$(bash "$root/install.sh" 2>&1)"
[[ "$first" == *"Installed Agent Letterbox for Rex."* && "$first" == *"letterbox rex setup --agents"* ]] \
  || { printf 'FAIL: a first install gives the setup command:\n%s\n' "$first" >&2; exit 1; }

again="$(bash "$root/install.sh" 2>&1)"
version="$(<"$tmp/install/VERSION")"
[[ "$again" == *"Updated Agent Letterbox for Rex to $version."* ]] \
  || { printf 'FAIL: an update says it updated:\n%s\n' "$again" >&2; exit 1; }
[[ "$again" != *"setup --agents"* ]] \
  || { printf 'FAIL: an update prints the first-time setup:\n%s\n' "$again" >&2; exit 1; }

# Since 0.6.4 setup also links the Agent Letterbox skill into ~/.claude/skills,
# but an update says there is nothing more to run, so a team set up earlier
# never got the link (28 Oct).
# The update makes it where setup would have, and nowhere else.
mkdir -p "$tmp/stub"
for b in tmux cmux zellij herdr; do printf '#!/bin/sh\nexit 0\n' > "$tmp/stub/$b"; chmod +x "$tmp/stub/$b"; done
bad() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
install() { # home [extra env...]
  local home="$1"; shift
  env -i HOME="$home" PATH="/usr/bin:/bin" AGENT_LETTERBOX_REPO="$tmp/source" \
    AGENT_LETTERBOX_INSTALL_DIR="$home/install" AGENT_LETTERBOX_BIN_DIR="$home/bin" \
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=maintenance.auto GIT_CONFIG_VALUE_0=false "$@" \
    bash "$root/install.sh" 2>&1
}
set_up() { # home: install, then the skill link an earlier setup would have left
  mkdir -p "$1/.agents/skills"
  install "$1" >/dev/null
  ln -s "$(cd "$1/install/bin" && pwd)/../skills/agent-letterbox" \
    "$1/.agents/skills/agent-letterbox"
}
claude_skill=".claude/skills/agent-letterbox"

H="$tmp/older-team"; set_up "$H"; mkdir -p "$H/.claude"
out="$(install "$H")"
[[ -L "$H/$claude_skill" ]] || bad "an update links the Agent Letterbox skill into ~/.claude/skills ($out)"
[[ "$(readlink "$H/$claude_skill")" == "$(readlink "$H/.agents/skills/agent-letterbox")" ]] \
  || bad "to the same skill as the shared link, so setup later sees it as its own"
[[ "$out" == *"Agent Letterbox skill also linked: $H/$claude_skill"* && "$out" == *"nothing more to run"* ]] \
  || bad "the update says so, and that nothing more is needed ($out)"
out="$(install "$H")"
[[ "$out" != *"skill also linked"* ]] || bad "a second update changes nothing ($out)"

H="$tmp/own-skill"; set_up "$H"; mkdir -p "$H/$claude_skill"; printf 'mine\n' > "$H/$claude_skill/SKILL.md"
install "$H" >/dev/null
[[ ! -L "$H/$claude_skill" && "$(ls -A "$H/$claude_skill")" == SKILL.md && "$(cat "$H/$claude_skill/SKILL.md")" == mine ]] \
  || bad "an existing ~/.claude skill is left alone"

H="$tmp/no-claude"; set_up "$H"
install "$H" >/dev/null
[[ ! -e "$H/.claude" ]] || bad "nothing is created without ~/.claude"

H="$tmp/custom-dir"; set_up "$H"; mkdir -p "$H/.claude"
install "$H" LETTERBOX_SKILLS_DIR="$tmp/skills" >/dev/null
[[ ! -e "$H/$claude_skill" ]] || bad "LETTERBOX_SKILLS_DIR is respected"

H="$tmp/not-set-up"; mkdir -p "$H/.claude"; install "$H" >/dev/null
install "$H" >/dev/null
[[ ! -e "$H/$claude_skill" ]] || bad "no link before setup has run; setup makes it"

# This edition's versions are whole numbers. An update names the new version
# and does not announce an older three-part number.
[[ "$again" != *"0.7."* ]] || bad "an update announces an old three-part number"
git -C "$tmp/source" checkout -q -b across
printf '0.7.0\n' > "$tmp/source/VERSION"
git -C "$tmp/source" -c user.name=t -c user.email=t@example.invalid commit -q -am 'stand-in old number'
AGENT_LETTERBOX_INSTALL_DIR="$tmp/across" AGENT_LETTERBOX_BIN_DIR="$tmp/across-bin" bash "$root/install.sh" >/dev/null 2>&1
printf '%s\n' "$version" > "$tmp/source/VERSION"
git -C "$tmp/source" -c user.name=t -c user.email=t@example.invalid commit -q -am 'back to this version'
across="$(AGENT_LETTERBOX_INSTALL_DIR="$tmp/across" AGENT_LETTERBOX_BIN_DIR="$tmp/across-bin" bash "$root/install.sh" 2>&1)"
[[ "$across" != *"0.7."* ]] || bad "an update from an old number still speaks in that numbering: $across"
[[ "$across" == *"Updated Agent Letterbox for Rex to $version."* ]] \
  || bad "an update from an old number does not name this version: $across"

printf '%s\n' 'install update suite: PASS'
