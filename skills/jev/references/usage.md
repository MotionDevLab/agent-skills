# Jev usage: 3 cases where Jev beats local

## 1. High-stakes routing with a long tail

State: enterprise support tickets with contract language in several languages.
Laya routes the common cases; tickets below its confidence threshold go to Jev
as a choice over handlers with typed arguments. Why Jev: the cost of a misroute
(client escalation) dwarfs the fraction-of-a-cent call, and multilingual quality
is measurably better on the tail.

## 2. Extraction cascade

State: invoices in mixed layouts. Laya answers a presence noul ("contains a
total-due field?"); only present-and-uncertain documents go to Jev for value
selection over candidate spans. Why Jev: most documents never need the paid
call, and the cascade keeps the average cost near zero while accuracy matches
an all-cloud pipeline.

## 3. Citation verification before publishing

State: a drafted answer plus its source passages. Jev judges each claim against
evidence (one noul per claim) and anything failing goes to a human. Why Jev:
calibrated yes/no probabilities on long multilingual contexts is exactly where
the larger model earns its keep; Laya stays on the cheap pre-filter.
