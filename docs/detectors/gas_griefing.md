# gas_griefing

- Detector ID: gas_griefing
- Severity: Medium
- Confidence: Low

## Purpose

Detects unbounded loops in external functions where the iteration count could be controlled by an external caller, enabling gas griefing attacks.

## Detection Logic

Uses CFG natural loop detection. For each loop body containing array iteration (`array_len`, `array_get`, `array_pop_front`), checks if external call blocks are forward-reachable from within the loop body. The combination of unbounded iteration and external calls creates a gas amplification vector.

## False Positives / False Negatives

- FP: Loops with bounded iteration (e.g., fixed-size arrays or explicit length checks).
- FN: Indirect iteration patterns not recognized as loops.

## Recommended Remediation

Bound loop iterations with an explicit maximum. Consider pagination patterns for processing large arrays. Use gas estimation to reject transactions that would consume excessive gas.
