# pragma_unchecked_num_sources

- Detector ID: pragma_unchecked_num_sources
- Severity: Medium
- Confidence: Low

## Purpose

Detects Pragma oracle price consumption without checking the number of reporting sources. A low source count makes price manipulation significantly easier.

## Detection Logic

Scans for Pragma price feed calls and checks whether `num_sources`, `num_sources_aggregated`, or `min_sources` is validated before the price data reaches storage writes or external calls.

## False Positives / False Negatives

- FP: Source count may be guaranteed by the oracle contract configuration.
- FN: Custom source validation using non-standard naming.

## Recommended Remediation

Check `num_sources_aggregated` against a minimum threshold (e.g., >= 3) before using oracle prices.
