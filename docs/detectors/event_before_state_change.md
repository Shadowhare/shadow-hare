# event_before_state_change

- Detector ID: event_before_state_change
- Severity: Low
- Confidence: Low

## Purpose

Detects event emissions that occur before the state change they describe is finalized. If the transaction reverts after the event, indexers will record inconsistent state.

## Detection Logic

Uses CFG-based forward reachability. For each block containing `emit_event`, checks if a `storage_write` block is forward-reachable. If so, the event is on an executable path before the state is committed — the risky ordering pattern. The safe pattern is storage_write followed by emit_event.

## False Positives / False Negatives

- FP: Events that intentionally describe pre-state (e.g., "Transfer requested").
- FN: Events emitted through helper functions that are not inlined.

## Recommended Remediation

Emit events after the state change is finalized (Checks-Effects-Interactions-Events pattern).
