---
name: laya
description: Local System One decision engine for zero-cost, offline-capable typed judgments. Use for routing, triage, scoring, verification, and guardrails when the task fits a small local model; escalate to jev when confidence is low or stakes are high.
---

# Laya

Laya is a local System One decision engine: it turns natural language plus application
state into typed answers (choice, score, yes/no with reason) with calibrated probabilities,
in a single forward pass on local CPU/GPU. Zero cost, no API key, no data leaving the machine.
Multilingual: 100+ languages via the multilingual checkpoint.

## What Laya is

- Small language model running locally (Ollama preferred, llama.cpp fallback), CPU-friendly.
- One forward pass per question: no agentic loops, no chain-of-thought needed for routine calls.
- Returns typed judgments your code can combine: choices, scores, booleans with reasons.
- Free for unlimited calls, works offline once weights are downloaded.

## When to use it

- Routing: which handler, queue, or template fits this input?
- Triage: how urgent / which category / spam-or-not?
- Scoring: rank, rate, or grade items with calibrated numbers.
- Verification: does this output satisfy the guardrail? yes/no with reason.
- Any high-volume, low-stakes judgment where a large model is overkill.

Escalate to `jev` when Laya reports low confidence, the decision is high-stakes or
irreversible, or multilingual quality is insufficient. See `skills/_shared/decision-contract.md`.

## How to invoke it

Ask typed questions against a state (text, ticket, JSON):

- `choice`: pick one of N named options, returns option + probability per option.
- `score`: rate on a numeric scale, returns value + calibrated confidence.
- `noul` (yes/no with reason): boolean + one-line reason + confidence.

Every answer carries a calibrated probability. Treat probability below your task
threshold as "ask jev or a human", never as a quiet yes. Thresholds live in the
calling code, not in this file.

## Backend selection

1. Ollama (preferred): `ollama list` shows the pinned model from `config.example.json`. Start here.
2. llama.cpp fallback: direct `llama-cli` run against `weights/` when Ollama is absent.
3. Order is fixed: Ollama, then llama.cpp. Do not add cloud fallbacks to this skill; cloud escalation is the `jev` skill's job.

Setup and model download: `python scripts/laya-setup.py --download` then `--verify`.
Runtime entrypoint: `scripts/laya-run.py` (planned; until it lands, `laya-setup.py --verify` is the smoke test).

## Examples

- Support inbox router: choice over {refund, bug, howto, other} with per-option probability; below-threshold goes to human review.
- Content triage: score 1-5 urgency plus noul "violates policy?" guardrail check before publishing.
- Form filling copilot: choice over next-field candidates given half-filled state; calibrated scores drive the suggestion order.

Worked prose for each: `references/usage.md`.
