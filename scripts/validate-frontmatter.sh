#!/usr/bin/env bash
# Redundant frontmatter validator — hedges against skills-ref alpha-status breakage.
# Checks stable spec rules that are unlikely to change:
#   1. SKILL.md exists
#   2. Starts with YAML frontmatter (--- ... ---)
#   3. `name` field matches parent directory name
#   4. `name` is 1-64 chars, kebab-case, no leading/trailing/consecutive hyphens
#   5. `description` is 1-1024 chars, non-empty
#   6. Frontmatter is strict-YAML parseable (catches unquoted `: ` in descriptions,
#      which otherwise silently produces a broken Skill tool description and
#      blocks auto-activation). Requires python with PyYAML; skipped with a
#      warning if unavailable.
# Exits 0 on all-green, 1 on any failure, 2 on usage error.
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: bash scripts/validate-frontmatter.sh <skill-dir1> [skill-dir2] ..."
  exit 2
fi

rc=0
for dir in "$@"; do
  dir="${dir%/}"
  skill_name="$(basename "$dir")"
  file="$dir/SKILL.md"

  if [ ! -f "$file" ]; then
    echo "FAIL $skill_name: missing SKILL.md"; rc=1; continue
  fi

  # Extract frontmatter between the first two --- markers
  fm="$(awk '/^---$/{c++; if(c==2) exit} c>=1{print}' "$file" | tail -n +2)"
  if [ -z "$fm" ]; then
    echo "FAIL $skill_name: no YAML frontmatter"; rc=1; continue
  fi

  name="$(echo "$fm" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')"
  if [ "$name" != "$skill_name" ]; then
    echo "FAIL $skill_name: name field '$name' does not match parent dir"; rc=1; continue
  fi
  if ! echo "$name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    echo "FAIL $skill_name: name '$name' not valid kebab-case"; rc=1; continue
  fi
  if [ ${#name} -gt 64 ]; then
    echo "FAIL $skill_name: name length > 64"; rc=1; continue
  fi

  # Description may span multiple lines if folded; capture from `description:` to next top-level key
  desc="$(echo "$fm" | awk '/^description:/{f=1; sub(/^description:[[:space:]]*/,""); print; next} f && /^[a-z-]+:/{f=0} f')"
  desc_len=${#desc}
  if [ -z "$desc" ]; then
    echo "FAIL $skill_name: description missing or empty"; rc=1; continue
  fi
  if [ "$desc_len" -gt 1024 ]; then
    echo "FAIL $skill_name: description length $desc_len > 1024"; rc=1; continue
  fi

  # Strict YAML parse — catches unquoted `: ` which breaks the Skill tool's description field
  if command -v python >/dev/null 2>&1; then py=python
  elif command -v python3 >/dev/null 2>&1; then py=python3
  else py=""; fi
  if [ -n "$py" ]; then
    if ! "$py" -c "
import sys, yaml, re
with open(r'''$file''', encoding='utf-8') as f:
    content = f.read()
m = re.match(r'---\r?\n(.*?)\r?\n---', content, re.DOTALL)
if not m:
    sys.exit(10)
try:
    data = yaml.safe_load(m.group(1))
    if not isinstance(data, dict):
        sys.exit(11)
    if not isinstance(data.get('description', ''), str) or not data.get('description'):
        sys.exit(12)
except yaml.YAMLError as e:
    print('YAML error: ' + str(e).splitlines()[0], file=sys.stderr)
    sys.exit(13)
" 2>/tmp/yaml-err.$$; then
      err="$(cat /tmp/yaml-err.$$ 2>/dev/null || true)"; rm -f /tmp/yaml-err.$$
      echo "FAIL $skill_name: strict YAML parse failed${err:+ — }${err}"; rc=1; continue
    fi
  fi

  echo "OK   $skill_name"
done
exit $rc
