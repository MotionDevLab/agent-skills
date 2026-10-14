# Laya usage: 3 canonical cases

## 1. Router

State: an incoming item (support ticket, email, event). Question: choice over handler
names. Use the per-option probabilities to route: top option above threshold wins;
anything below threshold goes to a default queue plus a low-confidence flag for sampling.
Why Laya: thousands of calls a day, each trivial alone, expensive in aggregate on paid APIs.

## 2. Triage

State: a piece of user content plus queue context. Questions: score urgency 1-5, then
noul "does this violate policy?". Publish only on noul-no with high confidence; route
everything else to human review. Why Laya: the guardrail must run on every item including
offline and in regions where cloud calls are unwanted.

## 3. Guardrail verification

State: a draft output plus the rule it must satisfy. Question: noul "satisfies rule?"
with reason. The reason string is logged for audit; the boolean gates the pipeline.
Why Laya: verification runs per output, often multiple rules per output; local
single-pass inference keeps latency flat and cost at zero.
