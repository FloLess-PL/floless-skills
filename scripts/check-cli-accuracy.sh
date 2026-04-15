#!/usr/bin/env bash
# Local-only CLI-accuracy validator (requires FloLess desktop running per D-11b).
# Parses skills/**/*.md for `floless ...` invocations in fenced code blocks and
# runs each against the live CLI. Asserts exit code 0 + envelope success==true
# for happy-path examples.
#
# Security (T-69.2-07): uses `read -ra argv <<< "$cmd"` to split into an argv
# array, then runs `"${argv[@]}"` — NO eval, NO shell interpolation of harvested
# content. Shell metacharacters in harvested strings pass through as literal CLI
# args which fail at the floless argparser level.
#
# Usage: bash scripts/check-cli-accuracy.sh [skills_root]
#   skills_root defaults to "skills/" if not provided.
set -euo pipefail

ROOT="${1:-skills}"
[ -d "$ROOT" ] || { echo "usage: check-cli-accuracy.sh [skills_root]" >&2; exit 2; }

# Preflight: FloLess desktop must be reachable
if ! floless nodes --json 2>/dev/null | jq -e '.success == true' > /dev/null; then
  echo "ERROR: FloLess desktop not reachable. Run 'floless start' or open the desktop app, then retry." >&2
  exit 2
fi

rc=0
count=0
found_any_files=0

# Find all markdown files under skills/, walk each
while IFS= read -r -d '' file; do
  found_any_files=1
  lineno=0
  in_code=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno+1))
    # Strip trailing CR for CRLF-encoded files (skills authored on Windows)
    line="${line%$'\r'}"
    # Toggle fenced code blocks
    if [[ "$line" =~ ^\`\`\`(bash|shell|sh|console|text)?$ ]]; then
      in_code=$((1 - in_code)); continue
    fi
    # Match floless invocations that start a line inside a fenced code block
    if [[ "$line" =~ ^floless[[:space:]] ]] && [ "$in_code" = "1" ]; then
      cmd="$line"
      count=$((count+1))
      # Run via argv array (no eval) — use bash read -ra to split
      read -ra argv <<< "$cmd"
      if ! out=$("${argv[@]}" 2>&1); then
        printf 'FAIL  %s:%d  %s\n       exit code non-zero\n       %s\n' "$file" "$lineno" "$cmd" "$out"
        rc=1
        continue
      fi
      # If invocation includes --json flag, validate envelope shape
      if echo "$cmd" | grep -q -- '--json'; then
        if ! echo "$out" | jq -e '.success == true' > /dev/null 2>&1; then
          printf 'FAIL  %s:%d  %s\n       envelope success != true\n       %s\n' "$file" "$lineno" "$cmd" "$out"
          rc=1
          continue
        fi
      fi
      printf 'OK    %s:%d  %s\n' "$file" "$lineno" "$cmd"
    fi
  done < "$file"
done < <(find "$ROOT" -name '*.md' -type f -print0 2>/dev/null)

if [ "$found_any_files" = "0" ]; then
  echo "No markdown files under $ROOT/ — nothing to check (graceful no-op)."
  exit 0
fi

if [ "$count" = "0" ]; then
  echo "Walked $ROOT/ but found no floless invocations in fenced code blocks."
fi

exit $rc
