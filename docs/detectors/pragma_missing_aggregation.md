# pragma_missing_aggregation

- Detector ID: pragma_missing_aggregation
- Severity: Medium
- Confidence: Low

## Purpose

Detects Pragma oracle price consumption without aggregation mode verification. Single-source prices are more susceptible to manipulation than aggregated (median/TWAP) prices.

## Detection Logic

Scans for Pragma price feed calls and checks whether the code verifies or specifies an aggregation mode (`median`, `twap`, `aggregation_mode`). If price data flows to storage or external calls without aggregation context, a finding is emitted.

## False Positives / False Negatives

- FP: Aggregation may be enforced at the Pragma contract level via configuration.
- FN: Non-standard aggregation patterns not recognized.

## Recommended Remediation

Use aggregated price feeds (median or TWAP) and verify the aggregation mode before consuming oracle data.
