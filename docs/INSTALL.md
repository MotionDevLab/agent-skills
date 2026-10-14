# INSTALL

One command sets up every skill on a machine: model weights (Laya) plus skill
links for each detected harness. Re-running is always safe (idempotent).

## One-liners

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/MotionDevLab/agent-skills/main/scripts/install.ps1 | iex
```

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/MotionDevLab/agent-skills/main/scripts/install.sh | bash
```

## Where skills land (verified paths)

| Harness | Skills dir | Detected when |
|---|---|---|
| Claude Code | `~/.claude/skills` | `~/.claude` exists |
| OpenCode | `~/.config/opencode/skills` | `~/.config/opencode` exists |
| OpenClaude | `~/.openclaude/skills` | `~/.openclaude` exists |

`auto` (the default) links only detected harnesses. No harness found is an error
with guidance, never a silent no-op. Override with `-Harness` / `--harness`.

Shared-convention alternative: `~/.agents/skills` also works as a manual target
(copy or symlink a skill folder there); the installer does not manage it so two
harnesses never fight over one link.

## Flags

PowerShell: `-Skills laya|jev|all` (default `all`), `-Harness auto|claude|opencode|openclaude|all`
(default `auto`), `-NoModel` (skill files only, skip weights), `-WhatIf` (print targets, write nothing).

Bash: `--skills`, `--harness`, `--no-model`, `--what-if`. Same meanings.

## Model bootstrap

Unless `-NoModel`, the installer runs `laya-setup.py --download --verify` before
linking: Ollama pull when Ollama is present, else resumable GGUF download with
checksum into `weights/` (gitignored, never committed). Python 3.10+ is required;
a missing Python is a loud error naming the fix, not a silent skip.

## Offline re-run

Already-downloaded weights are skipped by checksum; already-linked skills report
`already-installed` and exit 0. A second run with no network and warm caches
succeeds end to end.
