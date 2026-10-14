# agent-skills

Harness-agnostic agent skills by MotionDevLab. One repo, every harness, free-local-first.

Skills ship as plain folders (`skills/<name>/` with `SKILL.md` + `skill.json`) that load
unmodified in Claude Code, OpenCode, and OpenClaude. No lock-in, no registry account.

## Skills

| Skill | Cost | Backend | When to use it |
|---|---|---|---|
| `laya` | free, local, offline-capable | Ollama preferred, llama.cpp fallback | Default: routing, triage, scoring, guardrail verification |
| `jev` | very cheap, paid API | TypeSafe native endpoint, Vercel Gateway fallback | Escalation: low confidence, high stakes, multilingual quality gaps |

Routing rule: default to Laya for zero-cost/offline; escalate freely to very-cheap Jev on
low confidence (cost is negligible, so the threshold stays low) or explicit request.
See `skills/_shared/decision-contract.md`.

## One-command install

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/MotionDevLab/agent-skills/main/scripts/install.ps1 | iex
```

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/MotionDevLab/agent-skills/main/scripts/install.sh | bash
```

What it does: detects OS, ensures Python 3.10+, downloads the Laya model weights
(`--NoModel` skips this), then symlinks-or-copies each skill into every harness it finds
(`~/.claude/skills`, `~/.config/opencode/skills`, `.agents/skills`). Re-running is safe:
already-installed skills are reported, not duplicated. Details: `docs/INSTALL.md`.

## Add a skill in 3 steps

1. Copy the template: `templates/new-skill/` to `skills/<name>/`, fill in the TODOs.
2. Register it in root `skill.json` and check the installer picks it up (`install.ps1 -WhatIf`).
3. Run `scripts/lint-repo.ps1` (must PASS) and open a PR. Full guide: `docs/ADD-A-SKILL.md`.
