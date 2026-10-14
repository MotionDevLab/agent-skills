# Decision contract: Laya vs Jev

Both skills honor the same typed interface (`choice`, `score`, `noul` with
calibrated probabilities), so routing switches backends, never shapes.

## Rule

Default to Laya. Escalate to Jev on:

1. Low confidence: Laya's probability below the task threshold. Cost is
   negligible so the threshold stays low; when in doubt, escalate.
2. High stakes: irreversible, financial, access-control, or published outcomes.
3. Quality gap: the needed language or judgment shape beats the local model.
4. Explicit flag: user or calling code names `jev`.

## Non-rules

- Never route to Jev for offline work; fail to Laya-only with a note instead.
- Never treat Jev confidence as permission to act; thresholds are evaluated on
  your data and consequences.
- Never put keys in repo files; missing keys fail with setup instructions
  (see `skills/jev/SKILL.md` Auth), never a raw 401 dump.

## Adding a third backend later

Copy this contract's shape: same three primitives, a named escalation rule with
its cost/latency/quality trade, and auth-via-env-vars. Register in root
`skill.json`, extend installer `-Skills`, add a row to the README table.
