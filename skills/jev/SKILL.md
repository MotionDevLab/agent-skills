---
name: jev
description: TypeSafe Jev, the very-cheap paid cloud alternative to Laya for typed System One judgments. Use when local confidence is low, stakes are high, or multilingual quality matters; same choice/score/noul interface as laya via Vercel Gateway or the native TypeSafe endpoint.
---

# Jev

<!-- Adapted from the upstream TypeSafe skill (https://github.com/typesafe-ai/skills/blob/main/skills/typesafe-ai/SKILL.md, fetched 2026-10-14). This file is an adaptation for the agent-skills routing model, not a copy: structure and emphasis are our own, concepts follow upstream. Re-check upstream when behavior changes. -->

Jev is TypeSafe's flagship System One model: it turns natural language and
application state into typed answers with calibrated probabilities, like Laya,
but runs in the cloud with a larger model behind it. Very cheap per call, still
paid, still needs keys and network. That is the whole trade: Laya by default,
Jev when the judgment matters more than the fraction of a cent.

## When to use Jev over Laya

- Low local confidence: Laya's probability falls below your task threshold.
- High stakes: irreversible actions, money, access control, published content.
- Multilingual gaps: quality in the needed language beats the local checkpoint.
- Richer judgments: extraction, reranking, multi-question fan-out over one state,
  where the upstream cookbooks show a decomposition worth borrowing.
- Explicit request: the user or calling code names jev.

Otherwise stay on Laya. Cost negligible is not cost zero, and offline still matters.

## Install

One installation method only, picked by harness.

Claude Code:

```text
claude plugin marketplace add typesafe-ai/skills
claude plugin install typesafe@typesafe-ai
```

Any other agent:

```text
npx skills add typesafe-ai/skills --skill typesafe-ai
```

Then link this repo's `skills/jev` wrapper with the repo installer so routing
(`laya` vs `jev`) works the same everywhere:

```powershell
powershell -File scripts\install.ps1 -Skills jev
```

## Auth

Two keys, both via env vars, never committed:

- `TYPESAFE_API_KEY`: native TypeSafe endpoint (preferred backend).
- `VERCEL_GATEWAY_KEY`: Vercel AI Gateway (fallback backend).

Backend order is fixed: native endpoint first, Gateway fallback. Missing keys
must fail with setup instructions naming the two env vars above, never with a
raw 401 dump. Keep keys server-side in web apps.

## How to invoke it

Same typed interface as Laya so calling code switches backends, not shapes:

- `choice`: one of a defined set; the distribution compares competing options.
- `noul`: whether a condition holds; probability of yes, no separate confidence.
- `score`: degree along a described dimension; probability-weighted position on ordered levels.

Design rules (adapted from upstream guidance): give each question enough state
(source text, identities, policies, facts, preferably named JSON fields); put the
judgment in instructions and its possible answers in criteria; one narrow judgment
per question; ask independent questions over the same state together; thresholds
are evaluated on your data and consequences, never borrowed blindly. Start from
the live docs index (https://docs.typesafe.ai/llms.txt) and the cookbook closest
to your workflow before inventing a decomposition.

## Confidence and escalation

Choice/Score confidence summarizes distribution concentration, not permission to
act. A Noul near 0.5 means yes and no are similarly probable, not medium
intensity. Spread probability across acceptable alternatives is normal for
harmless preferences. Escalate to a human or reasoning model on: failing
verification checks, below-threshold confidence on consequential branches, and
any serious-violation rule (which needs separate conditions, not a weighted score).

Full routing contract: `skills/_shared/decision-contract.md`.
Worked cases: `references/usage.md`.
