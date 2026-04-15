#!/usr/bin/env bash
# floless-skills health check — run this to verify end-to-end readiness.
# Requires: floless CLI installed on PATH, FloLess desktop app running (Windows only).
# Usage: bash scripts/health-check.sh [--full]
#   --full  enables step 10 (workflow list — requires a loaded workflow)
set -euo pipefail

FULL=0
[[ "${1:-}" == "--full" ]] && FULL=1

step() { printf '  %2d. %s ... ' "$1" "$2"; }
ok()   { printf 'OK\n'; }
fail() { printf 'FAIL\n%s\n' "$1"; exit 1; }

echo "FloLess Skills health check"
echo

step  1 "floless --version"
out=$(floless --version 2>&1) || fail "$out"
ok

step  2 "port file exists"
port_file="${LOCALAPPDATA:-$HOME/AppData/Local}/FloLess/cli-api.port"
[ -f "$port_file" ] || fail "not found: $port_file"
ok

step  3 "floless nodes --json (end-to-end)"
out=$(floless nodes --json 2>&1) || fail "$out"
echo "$out" | jq -e '.success == true' > /dev/null || fail "envelope success=false: $out"
ok

step  4 "floless triggers --json"
floless triggers --json 2>&1 | jq -e '.success == true' > /dev/null || fail "triggers"
ok

step  5 "floless actions --json"
floless actions --json 2>&1 | jq -e '.success == true' > /dev/null || fail "actions"
ok

step  6 "floless schema --type workflow"
floless schema --type workflow > /dev/null 2>&1 || fail "schema workflow"
ok

step  7 "floless skills --json"
floless skills --json 2>&1 | jq -e '.success == true' > /dev/null || fail "skills"
ok

step  8 "floless templates --type smart --json"
floless templates --type smart --json 2>&1 | jq -e '.success == true' > /dev/null || fail "templates smart"
ok

step  9 "floless templates --type think --json"
floless templates --type think --json 2>&1 | jq -e '.success == true' > /dev/null || fail "templates think"
ok

if [ "$FULL" -eq 1 ]; then
  step 10 "floless workflow list --json (requires loaded workflow)"
  floless workflow list --json 2>&1 | jq -e '.success == true' > /dev/null || fail "workflow list"
  ok
fi

echo
echo "All checks passed."
