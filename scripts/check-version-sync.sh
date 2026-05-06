#!/usr/bin/env bash
# Enforce lockstep versioning across the plugin.
# Every skill's frontmatter `metadata.version` MUST equal `.claude-plugin/plugin.json`'s
# `.version`, which MUST equal `.claude-plugin/marketplace.json`'s plugin entry version.
#
# This is the convention `floless-update-skills` relies on for `MODE=copy` installs:
# the canary skill's version is treated as the installed plugin version, so any drift
# silently breaks update detection on direct-copy installs.
#
# Exits 0 on all-green, 1 on any drift, 2 on usage / missing tooling.
set -euo pipefail

require() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 2; }; }
require jq
require awk

plugin_file=".claude-plugin/plugin.json"
marketplace_file=".claude-plugin/marketplace.json"

[ -f "$plugin_file" ] || { echo "FAIL: $plugin_file not found" >&2; exit 2; }
[ -f "$marketplace_file" ] || { echo "FAIL: $marketplace_file not found" >&2; exit 2; }

plugin_version=$(jq -r '.version' "$plugin_file")
marketplace_version=$(jq -r '.plugins[] | select(.name=="floless") | .version' "$marketplace_file")

rc=0
printf '  %-40s %s\n' "plugin.json (.version)" "$plugin_version"
printf '  %-40s %s' "marketplace.json (floless.version)" "$marketplace_version"
if [ "$marketplace_version" != "$plugin_version" ]; then
  printf '  DRIFT (expected %s)\n' "$plugin_version"
  rc=1
else
  printf '  ok\n'
fi

for f in skills/*/SKILL.md; do
  skill=$(basename "$(dirname "$f")")
  v=$(awk '
    /^---$/ { c++; next }
    c==1 && /^  version:/ {
      gsub(/.*version:[[:space:]]*"?/,"")
      gsub(/".*/,"")
      print; exit
    }
  ' "$f")
  if [ -z "$v" ]; then
    printf '  %-40s %s  MISSING metadata.version\n' "$skill" "(none)"
    rc=1
    continue
  fi
  printf '  %-40s %s' "$skill" "$v"
  if [ "$v" != "$plugin_version" ]; then
    printf '  DRIFT (expected %s)\n' "$plugin_version"
    rc=1
  else
    printf '  ok\n'
  fi
done

if [ "$rc" -ne 0 ]; then
  echo
  echo "Version drift detected. Run scripts/bump-version.sh or sync manually so that:"
  echo "  - .claude-plugin/plugin.json:.version"
  echo "  - .claude-plugin/marketplace.json:.plugins[].version (name=floless)"
  echo "  - skills/*/SKILL.md:metadata.version"
  echo "all share the same value."
  exit 1
fi

echo
echo "All versions in lockstep at $plugin_version."
