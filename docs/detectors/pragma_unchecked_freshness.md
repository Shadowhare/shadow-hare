# pragma_unchecked_freshness

- Detector ID: pragma_unchecked_freshness
- Severity: Medium
- Confidence: Low

## Purpose

Detects consumption of Pragma oracle price feeds without an observable timestamp or freshness check. Stale oracle data can be exploited for price manipulation attacks.

## Detection Logic

Uses taint analysis seeded from Pragma price call results (`get_data_median`, `get_data`, `get_spot_median`, `get_twap`). Checks whether the tainted price data reaches a storage write or external call without passing through a freshness-related sanitizer (`last_updated_timestamp`, `timestamp`, `stale`, `max_age`).

## False Positives / False Negatives

- FP: Freshness checks performed in a called function (inter-procedural limitation).
- FN: Custom freshness logic using non-standard naming.

## Recommended Remediation

Always check `last_updated_timestamp` against a maximum staleness threshold before using oracle prices.
