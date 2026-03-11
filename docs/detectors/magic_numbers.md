# magic_numbers

- Detector ID: magic_numbers
- Severity: Info
- Confidence: Low

## Purpose

Detects large numeric literals used directly in arithmetic or comparisons without named constants. Magic numbers reduce code readability and maintainability, making security review harder.

## Detection Logic

Scans for `*_const<N>` libfuncs where N is a large value not in the exempt list. Exempt values include 0, 1, 2, common powers of 2, storage base address constants, and boolean constants.

## False Positives / False Negatives

- FP: Well-known protocol constants (e.g., ERC165 interface IDs) that are standard.
- FN: Magic numbers hidden behind intermediate computations.

## Recommended Remediation

Replace magic numbers with named constants that describe their purpose (e.g., `const MAX_SUPPLY: u256 = 1000000`).
