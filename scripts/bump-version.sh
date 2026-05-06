#!/usr/bin/env bash
# Bump every version source in lockstep.
#
# Usage:
#   bash scripts/bump-version.sh patch     # 0.9.10 -> 0.9.11
#   bash scripts/bump-version.sh minor     # 0.9.x  -> 0.10.0
#   bash scripts/bump-version.sh major     # 0.x.x  -> 1.0.0
#   bash scripts/bump-version.sh 0.9.12    # explicit version
#
# Updates:
#   - .claude-plugin/plugin.json (.version)
#   - .claude-plugin/marketplace.json (.plugins[name=floless].version)
#   - skills/*/SKILL.md (metadata.version)
#
# Does NOT commit, tag, or push — review the diff, then commit yourself.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: bash scripts/bump-version.sh <patch|minor|major|X.Y.Z>" >&2
  exit 2
fi

arg="$1"
plugin_file=".claude-plugin/plugin.json"
marketplace_file=".claude-plugin/marketplace.json"

current=$(jq -r '.version' "$plugin_file")

case "$arg" in
  patch|minor|major)
    target=$(node -e "
      const [a,b,c] = '$current'.split('.').map(Number);
      const bump = '$arg';
      if (bump === 'major') console.log([a+1, 0, 0].join('.'));
      else if (bump === 'minor') console.log([a, b+1, 0].join('.'));
      else console.log([a, b, c+1].join('.'));
    ")
    ;;
  *)
    if [[ ! "$arg" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "Not a valid semver: $arg" >&2
      exit 2
    fi
    target="$arg"
    ;;
esac

echo "Bumping $current -> $target"

# plugin.json
tmp=$(mktemp)
jq --arg v "$target" '.version = $v' "$plugin_file" > "$tmp" && mv "$tmp" "$plugin_file"

# marketplace.json (only the floless entry)
tmp=$(mktemp)
jq --arg v "$target" '(.plugins[] | select(.name=="floless")).version = $v' "$marketplace_file" > "$tmp" && mv "$tmp" "$marketplace_file"

# skills
node -e "
const fs = require('fs');
const path = require('path');
const target = '$target';
for (const s of fs.readdirSync('skills')) {
  const f = path.join('skills', s, 'SKILL.md');
  if (!fs.existsSync(f)) continue;
  let txt = fs.readFileSync(f, 'utf8');
  const next = txt.replace(/^(\s*version:\s*)\"[^\"]*\"/m, '\$1\"' + target + '\"');
  if (next !== txt) {
    fs.writeFileSync(f, next);
    console.log('  ' + s);
  }
}
"

echo
echo "Done. Verify with: bash scripts/check-version-sync.sh"
echo "Then commit: git add -A && git commit -m 'release: v$target'"
