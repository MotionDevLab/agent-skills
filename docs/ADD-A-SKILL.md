# ADD-A-SKILL

How to add skill #3 and beyond. Total surface: one folder, one registry line, one installer check.

## Steps

1. Copy the template:
   `templates/new-skill/` to `skills/<name>/` (lowercase, no spaces).
   Fill in every TODO in `SKILL.md` + `skill.json`, add `references/usage.md`
   with 2-3 canonical cases as prose.
2. Register it: add `{"name":"<name>","path":"skills/<name>"}` to root `skill.json`.
3. Prove the installer picks it up:
   `powershell -File scripts\install.ps1 -Skills <name> -WhatIf`
   must list the skill under each detected harness. No installer code change
   should be needed: skill resolution is registry-driven by design. If you
   needed one, say so in the PR.
4. Run the gate: `powershell -File scripts\lint-repo.ps1` must print
   `RESULT: PASS` (extend the lint's required list if the new skill adds
   repo-level required files; skill payloads stay WARN-or-OK, never silent).
5. Live-check: `scripts\install.ps1 -Skills <name> -NoModel`, then re-run for
   the `already-installed` idempotency proof. Open the PR.

## 5-file checklist

- [ ] `skills/<name>/SKILL.md` (frontmatter `name:`, description, install/auth/backend sections)
- [ ] `skills/<name>/skill.json` (name, version, harness hints)
- [ ] `skills/<name>/references/usage.md` (2-3 cases, prose, no code dumps)
- [ ] Root `skill.json` registry entry
- [ ] Installer WhatIf output pasted in the PR (both `-Skills <name>` and default all)

## Rules (non-negotiable)

- ASCII-only file contents: repo tooling must parse under Windows PowerShell 5.1 without a BOM.
- No secrets: keys via env vars, documented by name; missing keys fail with setup instructions.
- No large binaries: downloaded at install time, gitignored, never committed.
- No verbatim upstream copies: adapt third-party skills, note source URL + date in-file.
- If the skill needs a shared routing rule with siblings, put it in `skills/_shared/` and link it from each skill.
