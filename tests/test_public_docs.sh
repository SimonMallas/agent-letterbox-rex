#!/usr/bin/env bash
# The fresh-install check must source the directory setup just wrote.
# A local SPEC anchor named from the docs must be a real heading.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

fence="$(awk '
  /Check, in that same terminal/ { grab=1; next }
  grab && /^```bash$/ { inside=1; next }
  grab && inside && /^```$/ { exit }
  grab && inside { print }
' README.md)"
[[ -n "$fence" ]] || fail "the fresh-install check fence is missing"
source_at="$(printf '%s\n' "$fence" | awk '/^source \/path\/to\/box\/env\.sh$/ { print NR; exit }')"
echo_at="$(printf '%s\n' "$fence" | awk '/^echo "\$LETTERBOX_DIR"$/ { print NR; exit }')"
[[ -n "$source_at" && -n "$echo_at" && "$source_at" -lt "$echo_at" ]] \
  || fail "the check must source /path/to/box/env.sh before it prints the directory"
setup_dirs="$(awk '/^## Install$/,/^## Register a block$/ { if (/--dir /) print }' README.md \
  | sed -n 's/.*--dir //p' | sort -u)"
[[ "$setup_dirs" == "/path/to/box" ]] \
  || fail "the install setup directory and the sourced env must be the same path: $setup_dirs"

python3 - "$root" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
spec = (root / "SPEC.md").read_text(encoding="utf-8")
slugs = set()
for heading in re.findall(r"^#{1,6}[ \t]+(.+)$", spec, re.M):
    text = heading.replace("`", "")
    slug = text.lower()
    slug = re.sub(r"[^\w\s-]", "", slug, flags=re.UNICODE)
    slug = re.sub(r"\s+", "-", slug).strip("-")
    slugs.add(slug)
misses = []
docs = list((root / "docs").glob("*.md")) + [root / "README.md", root / "SPEC.md"]
for path in docs:
    text = path.read_text(encoding="utf-8")
    for anchor in re.findall(r"SPEC\.md#([A-Za-z0-9._-]+)", text):
        if anchor not in slugs:
            misses.append(f"{path.name}#{anchor}")
if misses:
    sys.stderr.write("FAIL: SPEC anchor missing: " + ", ".join(misses) + "\n")
    sys.exit(1)
print(f"PASS: SPEC anchors ({len(slugs)} headings)")
PY

printf '%s\n' 'public docs: PASS'
