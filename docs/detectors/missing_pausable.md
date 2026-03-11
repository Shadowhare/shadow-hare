# missing_pausable

- Detector ID: missing_pausable
- Severity: Low
- Confidence: Low

## Purpose

Detects contracts with state-modifying external functions but no observable pause mechanism. Pausability is a safety net for DeFi contracts, allowing operators to halt operations during exploits or emergencies.

## Detection Logic

Checks if the contract has external functions that write to storage, then scans all function names for pause-related keywords (`pause`, `unpause`, `is_paused`, `emergency_stop`, `freeze`, `circuit_breaker`). Also checks for OpenZeppelin Pausable component usage. If no pause mechanism is found, a finding is emitted.

## False Positives / False Negatives

- FP: Simple contracts (e.g., tokens) where pausability is intentionally omitted.
- FN: Custom pause mechanisms with non-standard naming.

## Recommended Remediation

Integrate OpenZeppelin's Pausable component and apply `assert_not_paused()` guards on critical external functions.
