#!/usr/bin/env bash
# install.sh -- one-command skill auto-install for MotionDevLab/agent-skills (macOS/Linux).
# Mirrors scripts/install.ps1 flags and behavior.
#
#   curl -fsSL https://raw.githubusercontent.com/MotionDevLab/agent-skills/main/scripts/install.sh | bash
#   bash scripts/install.sh --what-if
#   bash scripts/install.sh --skills laya --no-model
#   bash scripts/install.sh --harness claude
set -euo pipefail

SKILLS="all"
HARNESS="auto"
NO_MODEL=0
WHAT_IF=0

while [ $# -gt 0 ]; do
  case "$1" in
    --skills) SKILLS="$2"; shift 2 ;;
    --skills=*) SKILLS="${1#--skills=}"; shift ;;
    --harness) HARNESS="$2"; shift 2 ;;
    --harness=*) HARNESS="${1#--harness=}"; shift ;;
    --no-model) NO_MODEL=1; shift ;;
    --what-if) WHAT_IF=1; shift ;;
    -h|--help)
      echo "usage: install.sh [--skills laya|jev|all] [--harness auto|claude|opencode|openclaude|all] [--no-model] [--what-if]"
      exit 0 ;;
    *) echo "ERROR: unknown flag $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
REGISTRY="$REPO_ROOT/skill.json"

fail() { echo "ERROR: $1" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || true
[ -f "$REGISTRY" ] || fail "registry not found: $REGISTRY (run from a full repo clone)"

# Registered skill names and paths (skill.json is the source of truth).
registered_names() { python3 -c "import json;print(' '.join(s['name'] for s in json.load(open('$REGISTRY'))['skills']))"; }
registered_path() { python3 -c "import json;print([s['path'] for s in json.load(open('$REGISTRY'))['skills'] if s['name']=='$1'][0])"; }

if [ "$SKILLS" = "all" ]; then
  WANTED="$(registered_names)"
else
  WANTED="$(echo "$SKILLS" | tr ',' ' ')"
fi
for name in $WANTED; do
  registered_names | tr ' ' '\n' | grep -qx "$name" || fail "unknown skill '$name' (registered: $(registered_names))"
done

harness_dir() {
  case "$1" in
    claude) echo "$HOME/.claude/skills" ;;
    opencode) echo "$HOME/.config/opencode/skills" ;;
    openclaude) echo "$HOME/.openclaude/skills" ;;
  esac
}
harness_marker() {
  case "$1" in
    claude) echo "$HOME/.claude" ;;
    opencode) echo "$HOME/.config/opencode" ;;
    openclaude) echo "$HOME/.openclaude" ;;
  esac
}

if [ "$HARNESS" = "auto" ]; then
  TARGETS=""
  for h in claude opencode openclaude; do
    [ -e "$(harness_marker "$h")" ] && TARGETS="$TARGETS $h"
  done
  [ -n "$TARGETS" ] || fail "no harness detected (looked for ~/.claude, ~/.config/opencode, ~/.openclaude). Pass --harness to choose explicitly."
elif [ "$HARNESS" = "all" ]; then
  TARGETS="claude opencode openclaude"
else
  harness_dir "$HARNESS" >/dev/null 2>&1 || fail "unknown harness '$HARNESS'"
  TARGETS="$HARNESS"
fi

python_ok() {
  command -v python3 >/dev/null 2>&1 || return 1
  python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)"
}

NEEDS_MODEL=0
echo "$WANTED" | tr ' ' '\n' | grep -qx "laya" && [ "$NO_MODEL" -eq 0 ] && [ "$WHAT_IF" -eq 0 ] && NEEDS_MODEL=1
if [ "$NEEDS_MODEL" -eq 1 ] && ! python_ok; then
  fail "Python 3.10+ is required for the Laya model bootstrap but was not found. Install Python 3.10+, or re-run with --no-model for skill files only."
fi

if [ "$WHAT_IF" -eq 1 ]; then
  echo "WhatIf: skills requested:$WANTED"
  echo "WhatIf: harness targets:"
  for h in $TARGETS; do
    echo "WhatIf:   [$h] $(harness_dir "$h")"
    for name in $WANTED; do
      echo "WhatIf:     link skill '$name' -> $(harness_dir "$h")/$name"
    done
  done
  if echo "$WANTED" | tr ' ' '\n' | grep -qx "laya"; then
    if [ "$NO_MODEL" -eq 1 ]; then echo "WhatIf: model bootstrap skipped (--no-model)";
    else echo "WhatIf: would run laya-setup.py --download --verify"; fi
  fi
  exit 0
fi

if [ "$NEEDS_MODEL" -eq 1 ]; then
  echo "Bootstrapping Laya model (this downloads weights on first run)..."
  python3 "$REPO_ROOT/scripts/laya-setup.py" --download --verify \
    || fail "laya-setup.py failed. Fix the error above, or re-run with --no-model for skill files only."
fi

linked=0; skipped=0
for h in $TARGETS; do
  dir="$(harness_dir "$h")"
  mkdir -p "$dir"
  for name in $WANTED; do
    src="$REPO_ROOT/$(registered_path "$name")"
    [ -e "$src" ] || fail "skill source missing: $src"
    link="$dir/$name"
    if [ -e "$link" ] || [ -L "$link" ]; then
      echo "already-installed: [$h] $name"
      skipped=$((skipped + 1))
      continue
    fi
    ln -s "$src" "$link"
    echo "linked: [$h] $name -> $src"
    linked=$((linked + 1))
  done
done

echo "Done: $linked linked, $skipped already-installed."
