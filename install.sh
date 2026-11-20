#!/usr/bin/env bash
# Agent Letterbox for Rex installer.
set -euo pipefail

repo="${AGENT_LETTERBOX_REPO:-}"
install_dir="${AGENT_LETTERBOX_INSTALL_DIR:-$HOME/.local/share/agent-letterbox-rex}"
bin_dir="${AGENT_LETTERBOX_BIN_DIR:-$HOME/.local/bin}"

fail() { printf 'agent-letterbox-rex installer: %s\n' "$*" >&2; exit 1; }
[[ -n "$repo" ]] || fail 'This edition has no published remote. Set AGENT_LETTERBOX_REPO to a git checkout of this tree.'
command -v git >/dev/null 2>&1 || fail 'Git is required. Install Git, then run this command again.'
if [[ -e "$install_dir" && ! -d "$install_dir/.git" ]]; then fail "$install_dir exists but is not an Agent Letterbox Git checkout"; fi
updated=false
if [[ -d "$install_dir/.git" ]]; then
  printf 'Updating Agent Letterbox for Rex in %s\n' "$install_dir"
  git -C "$install_dir" pull --ff-only
  updated=true
else
  printf 'Downloading Agent Letterbox for Rex...\n'
  mkdir -p "$(dirname "$install_dir")"
  git clone --depth 1 "$repo" "$install_dir"
fi
mkdir -p "$bin_dir"
launcher="$bin_dir/letterbox"
target="$install_dir/bin/letterbox"
if [[ -e "$launcher" || -L "$launcher" ]]; then
  [[ -L "$launcher" && "$(readlink "$launcher")" == "$target" ]] || fail "$launcher already exists. Choose one Letterbox platform, or set AGENT_LETTERBOX_BIN_DIR."
else
  ln -s "$target" "$launcher"
fi
chmod +x "$install_dir/bin/letterbox" "$install_dir/adapters"/*.sh "$install_dir/tests"/*.sh
# An update changes the code only. The first-time setup below is shared by the
# whole team, so an update must not present it as the next step.
if [[ "$updated" == true ]]; then
  printf '\nUpdated Agent Letterbox for Rex to %s.\n' "$(<"$install_dir/VERSION")"
  # An update links the skill where an earlier setup would have, when that
  # parent directory already exists and the shared skill points here.
  skill_source="$(cd "$install_dir/bin" && pwd)/../skills/agent-letterbox"
  claude_skill="$HOME/.claude/skills/agent-letterbox"
  if [[ -z "${LETTERBOX_SKILLS_DIR:-}" && -d "$HOME/.claude" && ! -e "$claude_skill" && ! -L "$claude_skill" \
        && "$(readlink "$HOME/.agents/skills/agent-letterbox" || true)" == "$skill_source" ]]; then
    mkdir -p "$HOME/.claude/skills"
    ln -s "$skill_source" "$claude_skill"
    printf 'Agent Letterbox skill also linked: %s\n' "$claude_skill"
  fi
  printf 'Your Letterbox, agents and registrations are unchanged. There is nothing more to run.\n'
  exit 0
fi
printf '\nInstalled Agent Letterbox for Rex.\n'
printf 'Next run:\n\n  letterbox rex setup --agents planner,reviewer,builder,researcher --dir <path>\n\n'
printf 'If `letterbox` is not found, add %s to your PATH.\n' "$bin_dir"
