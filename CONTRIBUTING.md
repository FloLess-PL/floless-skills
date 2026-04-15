# Contributing a new skill to floless-skills

Adding a new skill takes under 5 minutes. The scaffold, validation, and cross-link regeneration are automated.

## Add a new skill

1. **Scaffold** — run the scaffold script with the new skill name, a one-sentence description (what it does + when to use it), and a role:

   ```bash
   bash scripts/new-skill.sh floless-newthing "Does X. Use when the user wants Y." read-only
   ```

   Role choices:
   - `read-only` — skill only reads from the FloLess CLI (grants `Bash(floless:*) Read`)
   - `authoring` — skill also writes workflows or code (grants `Bash(floless:*) Read Write`)

   The script creates `skills/floless-newthing/SKILL.md` with a valid frontmatter block and a placeholder body, plus `skills/floless-newthing/references/.gitkeep`. It then regenerates the README skills table automatically.

2. **Author the body** — the scaffold produces a SKILL.md body with a `<!-- TODO: Invoke /skill-creator -->` marker. Invoke the `/skill-creator` skill (bundled at `C:\Users\<you>\.claude\skills\skill-creator\SKILL.md`) to author the body.

   **Do NOT hand-author the body.** Per project discipline D-17, every SKILL.md goes through `/skill-creator` for consistent frontmatter quality, description length, and cross-reference style.

3. **(Optional) Extend health-check** — if your skill exercises a `floless` CLI command not already in `scripts/health-check.sh`, add one step to the smoke test. Skip this if your skill's domain is already covered (nodes, triggers, actions, skills, templates, schema, workflow).

4. **Open a PR** — CI auto-runs on every push:
   - `skills-ref validate skills/*` — spec compliance
   - `bash scripts/validate-frontmatter.sh skills/*/` — redundant bash-belt check
   - `jq . .claude-plugin/*.json` — manifest lint

   Before merging, run the local CLI-accuracy check against a live FloLess desktop:

   ```bash
   bash scripts/check-cli-accuracy.sh skills/floless-newthing/
   ```

   This verifies that every `floless` invocation in your skill actually works and returns `success: true`.

## Refreshing plugin cache

After editing a skill locally while testing with `claude --plugin-dir ./`, run:

```
/reload-plugins
```

inside Claude Code to flush the cached skill definitions. (The correct command is `/reload-plugins`, not `/plugin reload`.)

## Conventions

- Use `{variable}` in prose descriptions, `{{variable}}` only in literal runtime `.flo` JSON strings (e.g., `{{trigger.cellValue}}`).
- Use `Display` not `DisplayNode` in node type names.
- Parse `errorCode` from the Stripe-style response envelope, not flat `error` strings.
- Check `data.compiled` (not `success`) for compile results — `success: true` can coexist with `compiled: false` when there are diagnostic errors.
- Prefer GUID-first lookup examples (`floless component <guid>`), name fallback second — names are not unique across providers.

## License

All contributions are licensed under the MIT license. See [LICENSE-skills](LICENSE-skills) for the full text.

## Questions

Open an issue at [github.com/FloLess-PL/floless-skills/issues](https://github.com/FloLess-PL/floless-skills/issues).
