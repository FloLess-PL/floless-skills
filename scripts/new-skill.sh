#!/usr/bin/env bash
# Scaffold a new skill in <5 minutes.
# Usage: bash scripts/new-skill.sh <name> "<description>" <role>
#   role = read-only | authoring
# Creates: skills/<name>/SKILL.md (with placeholder body)
#          skills/<name>/references/.gitkeep
# Then runs: scripts/generate-readme-toc.sh (unless SKIP_REGEN=1)
#
# Set SKIP_REGEN=1 to skip the regenerator (used in parallel wave-3 builds to
# prevent concurrent writes to README-skills.md and the overview cross-link file).
# Plan 10 runs the canonical final regen sweep after all skills exist.
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: bash scripts/new-skill.sh <name> \"<description>\" <role>"
  echo "  role = read-only | authoring"
  exit 2
fi

name="$1"
description="$2"
role="$3"

case "$role" in
  read-only) allowed_tools='Bash(floless:*) Read' ;;
  authoring) allowed_tools='Bash(floless:*) Read Write' ;;
  *) echo "role must be 'read-only' or 'authoring'"; exit 2 ;;
esac

# Kebab-case check — fail fast if user violates spec
if ! echo "$name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
  echo "Error: name '$name' is not kebab-case"; exit 2
fi

dir="skills/$name"
mkdir -p "$dir/references"
touch "$dir/references/.gitkeep"

cat > "$dir/SKILL.md" <<EOF
---
name: $name
description: $description
license: MIT
compatibility: Requires FloLess desktop app running and floless CLI installed. Windows only.
metadata:
  author: FloLess
  version: "1.0.0"
  cli-version-min: "1.0.0"
allowed-tools: $allowed_tools
---

# $name

<!-- TODO: Invoke /skill-creator to author the body. See CONTRIBUTING.md. -->

EOF

echo "Created $dir/SKILL.md"
echo "Next: invoke /skill-creator to fill the body, then run scripts/generate-readme-toc.sh"

if [[ "${SKIP_REGEN:-0}" != "1" ]]; then
  bash scripts/generate-readme-toc.sh
fi
