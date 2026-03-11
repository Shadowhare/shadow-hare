# unchecked_ecrecover

- Detector ID: unchecked_ecrecover
- Severity: High
- Confidence: Medium

## Purpose

Detects ECDSA signature verification calls (`ecdsa_recover`, `verify_ecdsa_signature`, `check_ecdsa_signature`, `secp256k1`, `secp256r1`) where the return value is not checked. Ignoring the verification result means invalid signatures are silently accepted, bypassing authentication.

## Detection Logic

Scans for invocations of ECDSA-related libfuncs. If the result is consumed by only one branch (the success path), the error/failure path is missing — the signature is effectively unchecked.

## False Positives / False Negatives

- FP: Wrapper functions that propagate the result to a caller that does check it.
- FN: Custom verification logic that checks the result through indirection.

## Recommended Remediation

Always check the return value of ECDSA verification functions. Handle the failure case explicitly (revert or return error).
