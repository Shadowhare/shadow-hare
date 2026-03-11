# uninitialized_storage_read

- Detector ID: uninitialized_storage_read
- Severity: Medium
- Confidence: Low

## Purpose

Detects external functions that read from storage when no observable write path exists in the program. In Starknet, uninitialized storage returns zero, which may cause logic errors (zero balance treated as valid, zero address used as owner).

## Detection Logic

Scans for `storage_read_syscall` in external functions. Then checks if any function in the program writes to storage (`storage_write_syscall`). If no writes exist, reads are flagged. Constructors and initializer-like functions count as writers. View/getter functions are excluded since read-only is their purpose.

## False Positives / False Negatives

- FP: Programs where storage is initialized by a factory or proxy pattern.
- FN: Storage initialized by a different contract that delegates to this one.

## Recommended Remediation

Ensure storage slots are initialized in the constructor or an initializer before being read. Add assertions for critical slots (e.g., `assert(owner != 0)`).
