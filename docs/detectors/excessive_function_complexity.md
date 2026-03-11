# excessive_function_complexity

- Detector ID: excessive_function_complexity
- Severity: Info
- Confidence: High

## Purpose

Detects functions with high cyclomatic complexity, making them difficult to test, review, and maintain. High complexity increases the risk of security bugs hiding in untested paths.

## Detection Logic

Computes cyclomatic complexity from the CFG: edges - nodes + 2. Functions exceeding a threshold of 20 are flagged. Only external functions are checked.

## False Positives / False Negatives

- FP: Functions that are inherently complex due to protocol requirements (e.g., multi-step validation).
- FN: Complexity hidden in called helper functions.

## Recommended Remediation

Refactor complex functions into smaller, focused helper functions. Each function should have a single responsibility and be independently testable.
