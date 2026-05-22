---
name: floless-update-skills
description: Update FloLess skills to the latest GitHub release. Use when the user wants to upgrade their installed floless-skills, check for new versions, or sync after a FloLess CLI release. Detects marketplace plugin vs git-clone vs direct skill-copy install layouts across Claude Code, Codex CLI, and OpenCode runtimes; compares the local plugin.json version to GitHub; shows the changelog between versions; and runs the right update path (plugin update, git pull, or recopy).
license: MIT
compatibility: Requires git and curl on PATH. Works on any platform; install layout detection covers Claude Code, Codex CLI, and OpenCode.
metadata:
  author: FloLess
  version: "0.9.18"
  upstream-repo: "FloLess-PL/floless-skills"
allowed-tools: Bash Read Write AskUserQuestion
---

# floless-update-skills

Update workflow for the `floless-skills` plugin. Mirrors `/gsd-update` but adapted for FloLess's git-and-marketplace distribution model. Detects how the user installed the skills, compares the local version against the upstream `main` branch on GitHub, shows what changed, asks for confirmation, then runs the right update path.

## When to use

The user wants to upgrade their floless-* skills, check whether a new version is available, or sync after a FloLess CLI release. Typical phrasings: "update floless skills", "is there a new version of floless-skills", "/floless-update-skills".

Do **not** use this skill to author or modify FloLess workflows — that is what `floless-workflows` and the other floless-* skills are for. This skill only updates the skills themselves.

## Process

<step name="detect_install">
Floless-skills can be installed three ways. Detect which one applies, in this order, for each runtime config dir.

For each runtime in `claude` (`~/.claude`), `codex` (`~/.codex`), `opencode` (`~/.opencode`):

1. **Marketplace plugin** — check `<config>/plugins/cache/floless-skills/floless/<version>/.claude-plugin/plugin.json`. The version segment varies; glob it. If found, set `MODE=plugin`, `ROOT=<that-version-dir>`.
2. **Git-clone repo install** — check `<config>/skills/floless-skills/.claude-plugin/plugin.json`. If found, set `MODE=git`, `ROOT=<config>/skills/floless-skills`.
3. **Direct skill copies** — check `<config>/skills/floless-canvas/SKILL.md` (canonical canary; this skill is in every release). If found, set `MODE=copy`, `ROOT=<config>/skills`.

```bash
detect_one() {
  local cfg="$1" runtime="$2"
  [ -d "$cfg" ] || return 1
  # 1) marketplace plugin
  for d in "$cfg"/plugins/cache/floless-skills/floless/*/; do
    if [ -f "$d/.claude-plugin/plugin.json" ]; then
      printf '%s\t%s\t%s\t%s\n' "plugin" "$runtime" "${d%/}" "$d/.claude-plugin/plugin.json"
      return 0
    fi
  done
  # 2) git clone
  if [ -f "$cfg/skills/floless-skills/.claude-plugin/plugin.json" ]; then
    printf '%s\t%s\t%s\t%s\n' "git" "$runtime" "$cfg/skills/floless-skills" "$cfg/skills/floless-skills/.claude-plugin/plugin.json"
    return 0
  fi
  # 3) direct skill copies (no plugin.json — version comes from SKILL.md metadata)
  if [ -f "$cfg/skills/floless-canvas/SKILL.md" ]; then
    printf '%s\t%s\t%s\t%s\n' "copy" "$runtime" "$cfg/skills" "$cfg/skills/floless-canvas/SKILL.md"
    return 0
  fi
  return 1
}

INSTALLS=()
for entry in "claude:$HOME/.claude" "codex:$HOME/.codex" "opencode:$HOME/.opencode"; do
  rt="${entry%%:*}"; cfg="${entry#*:}"
  out=$(detect_one "$cfg" "$rt") && INSTALLS+=("$out")
done
```

If `INSTALLS` is empty, print "No floless-skills install detected" and explain the three install methods from the README. Exit.

If `INSTALLS` has more than one entry, use `AskUserQuestion` to ask the user which install to update (one option per detected install, plus a "Cancel" option).

If `INSTALLS` has exactly one entry, proceed with it. Parse: `MODE`, `RUNTIME`, `ROOT`, `VERSION_FILE`.
</step>

<step name="read_installed_version">
For `MODE=plugin` and `MODE=git`, read `.version` from `plugin.json`:

```bash
INSTALLED_VERSION=$(node -e "console.log(require('$VERSION_FILE').version)" 2>/dev/null)
```

For `MODE=copy`, parse `metadata.version` from the canary `floless-canvas/SKILL.md` frontmatter. Per the lockstep convention (see *Convention notes*), every skill's `metadata.version` is kept identical to the plugin version on every release, so the canary stands in for the missing `plugin.json`:

```bash
INSTALLED_VERSION=$(awk '
  /^---$/ { c++; next }
  c==1 && /version:/ {
    gsub(/.*version:[[:space:]]*"?/,"")
    gsub(/".*/,"")
    print; exit
  }
' "$VERSION_FILE")
```

If `INSTALLED_VERSION` is empty, set it to `0.0.0` (treat as outdated).
</step>

<step name="read_latest_version">
Fetch the upstream `plugin.json` from GitHub:

```bash
LATEST_JSON=$(curl -fsSL https://raw.githubusercontent.com/FloLess-PL/floless-skills/main/.claude-plugin/plugin.json) || {
  echo "Failed to reach GitHub. Check your connection or run a manual update from $ROOT."
  exit 1
}
LATEST_VERSION=$(node -e "console.log(JSON.parse(process.argv[1]).version)" "$LATEST_JSON")
```
</step>

<step name="compare_versions">
Use `node -e "process.exit(...)"` for semver-aware comparison if available, otherwise fall back to string compare:

```bash
cmp=$(node -e "
const a='$INSTALLED_VERSION'.split('.').map(Number);
const b='$LATEST_VERSION'.split('.').map(Number);
for (let i=0;i<3;i++){
  if ((a[i]||0)<(b[i]||0)){console.log('older');process.exit()}
  if ((a[i]||0)>(b[i]||0)){console.log('newer');process.exit()}
}
console.log('equal');
")
```

- `equal` — print "Already on the latest version (`$LATEST_VERSION`)" and exit.
- `newer` — print "Local version `$INSTALLED_VERSION` is ahead of latest `$LATEST_VERSION`. Looks like a dev install — skipping update." and exit.
- `older` — proceed.
</step>

<step name="show_changelog">
Fetch commits between the installed version tag and `main`. The repo tags releases as `vX.Y.Z`, so compare `v$INSTALLED_VERSION...main`:

```bash
COMPARE_URL="https://api.github.com/repos/FloLess-PL/floless-skills/compare/v${INSTALLED_VERSION}...main"
LOG=$(curl -fsSL "$COMPARE_URL" 2>/dev/null | node -e "
let d=''; process.stdin.on('data',c=>d+=c).on('end',()=>{
  try {
    const j = JSON.parse(d);
    if (!j.commits) { console.log('(no commit data)'); return; }
    j.commits.forEach(c => {
      const sha = c.sha.slice(0,7);
      const msg = c.commit.message.split('\n')[0];
      console.log('  ' + sha + '  ' + msg);
    });
  } catch (e) { console.log('(could not parse compare response)'); }
}")
```

If the tag does not exist (e.g. user is on an unreleased version), fall back to "git log v0.9.0..main" guidance or just say "Changelog unavailable for this version range — see https://github.com/FloLess-PL/floless-skills/commits/main".

Print:
```
## floless-skills update available

Installed: $INSTALLED_VERSION  ($MODE @ $ROOT)
Latest:    $LATEST_VERSION
Runtime:   $RUNTIME

Changes since v$INSTALLED_VERSION:
$LOG
```
</step>

<step name="confirm">
Use `AskUserQuestion`:
- Question: "Update floless-skills from `$INSTALLED_VERSION` → `$LATEST_VERSION`?"
- Options:
  - "Yes, update now"
  - "No, cancel"

If user cancels, exit.
</step>

<step name="run_update">
Branch on `MODE`.

### MODE=plugin (marketplace install)

We cannot programmatically invoke `/plugin update` from a skill. Print:

```
This is a marketplace install. Run the built-in command to finish the update:

    /plugin update floless@floless-skills

Then restart your runtime to pick up the new skill definitions.
```

Exit.

### MODE=git (git-clone install)

Pull the upstream `main` branch:

```bash
git -C "$ROOT" fetch origin main --tags
git -C "$ROOT" pull --ff-only origin main
```

If `pull` fails because of local modifications, print the conflicting paths and tell the user to commit, stash, or revert before retrying. Do **not** force-pull or reset — that would destroy uncommitted work.

### MODE=copy (direct skill copies)

Clone the latest tag into a temp dir, then mirror each `skills/floless-*` directory into `$ROOT`. Only update skill folders that exist in the upstream release — never touch unrelated `floless-*` skills the user installed from elsewhere (e.g. `floless-blog-post-creator`, `floless-explainer`).

```bash
TMP=$(mktemp -d)
git clone --depth 1 --branch "v${LATEST_VERSION}" \
  https://github.com/FloLess-PL/floless-skills "$TMP" || \
  git clone --depth 1 https://github.com/FloLess-PL/floless-skills "$TMP"

for src in "$TMP"/skills/*/; do
  name=$(basename "$src")
  dest="$ROOT/$name"
  if [ -d "$dest" ]; then
    # Only update skills the user already has installed
    rm -rf "$dest"
    cp -r "$src" "$dest"
    echo "  updated: $name"
  fi
done

rm -rf "$TMP"
```

Skills present upstream but missing locally are skipped — adding new skills is opt-in. The user can copy them manually if they want them.
</step>

<step name="display_result">
Print a completion banner:

```
floless-skills updated: v$INSTALLED_VERSION → v$LATEST_VERSION
Mode: $MODE   Runtime: $RUNTIME   Root: $ROOT

Restart your runtime ($RUNTIME) to pick up the new skill definitions.

Full changelog: https://github.com/FloLess-PL/floless-skills/compare/v${INSTALLED_VERSION}...v${LATEST_VERSION}
```

For `MODE=plugin`, the banner instead reminds the user that `/plugin update floless@floless-skills` is the next step.
</step>

## Failure modes

- **No git or curl on PATH** — print install instructions for the user's platform and exit. Both are required.
- **GitHub unreachable** — print the `curl` error and exit. Suggest the user retry later or update manually with `git pull` in the install root.
- **Tag missing for `v$INSTALLED_VERSION`** — proceed without the changelog. Don't block the update.
- **Multiple installs detected** — always confirm via `AskUserQuestion` which one to update. Never update all of them silently.
- **`git pull` rejects** because of local edits — surface the conflict, do not `git reset`.

## Convention notes

- **Lockstep versioning** — `plugin.json` (`.version`), `marketplace.json` (the floless plugin entry's `.version`), and *every* `skills/*/SKILL.md` `metadata.version` share a single value. Releases bump them together. `scripts/bump-version.sh` does this in one shot; `scripts/check-version-sync.sh` enforces it in CI.
- **Why lockstep matters here** — `MODE=copy` installs have no `plugin.json` on disk, so this skill reads the canary skill's `metadata.version` as the installed plugin version. That only works if every skill is in lockstep with the plugin; otherwise drift silently breaks update detection. See `.github/workflows/validate.yml`.
- The upstream repo is hardcoded as `FloLess-PL/floless-skills`. If the repo ever moves, this skill needs a one-line patch.
