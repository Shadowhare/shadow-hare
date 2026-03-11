# shadowhare

**Slither for Starknet** — a production-grade static security analyzer for Cairo smart contracts.

[![Rust](https://img.shields.io/badge/rust-1.75%2B-orange)](https://www.rust-lang.org/)
[![License](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue)](LICENSE-MIT)
[![Detectors](https://img.shields.io/badge/detectors-71-red)]()
[![Tests](https://img.shields.io/badge/tests-156%20passing-brightgreen)]()

---

## The Problem

Cairo smart contracts on Starknet manage real assets. A single vulnerability — an unprotected upgrade, a reentrancy path, a missing nonce check — can drain millions. Manual audits are slow, expensive, and don't scale.

**Starknet has no Slither.** Until now.

## What Shadowhare Does

Shadowhare scans **compiled Sierra artifacts** (`.sierra.json` / `.contract_class.json`) and runs **71 security detectors** using CFG analysis, taint tracking, and dataflow engines — the same techniques behind Slither, but purpose-built for Cairo's Sierra IR.

No source code needed. Point it at compiled artifacts and get results in seconds.

## Key Features

- **71 security detectors** across 4 severity tiers (21 High / 26 Medium / 16 Low / 8 Info)
- **Deep analysis** — CFG construction, dominator trees, taint propagation, call graph analysis
- **Zero source required** — works directly on compiled `.sierra.json` and `.contract_class.json`
- **CI/CD ready** — SARIF 2.1.0 output, baseline diffing, deterministic exit codes
- **Scarb integration** — `scarb shadowhare detect` just works
- **Upgrade safety** — `detect-diff` compares two contract versions and flags regressions
- **Parallel execution** — detectors run concurrently via Rayon
- **External plugins** — extend with custom detectors via a simple JSON protocol
- **Tested against production contracts** — 0 high-severity false positives on Argent, OpenZeppelin, AVNU, and 30+ real mainnet contracts

---

## Quick Start

### Install from crates.io

```bash
cargo install shadowhare
```

### Install from source

```bash
git clone https://github.com/br0wnD3v/shadowhare.git
cd shadowhare
cargo install --path .
```

### Compile your contracts first

Shadowhare analyzes **compiled Sierra artifacts**, not Cairo source code. You must compile your contracts before scanning.

```bash
# If using Scarb (recommended)
scarb build
# Artifacts land in ./target/dev/*.contract_class.json

# If using the Cairo compiler directly
starknet-compile my_contract.cairo > my_contract.sierra.json
```

### Run

```bash
# Scan a contract
shdr detect ./target/dev/my_contract.contract_class.json

# Scan an entire project directory
shdr detect ./target/dev/

# Include info-level findings
shdr detect ./target/dev/ --min-severity info

# Output SARIF for CI pipelines
shdr detect ./target/dev/ --format sarif

# List all 71 detectors
shdr list-detectors
```

### With Scarb

```bash
# Build your project first
scarb build

# Run shadowhare as a Scarb subcommand
scarb shadowhare detect
scarb shdr detect
```

---

## Example Output

### Scanning Satoru (DeFi protocol — 36 contracts)

```
$ shdr detect ./satoru/target/dev/ --min-severity medium

shadowhare — satoru_Bank.contract_class.json, satoru_Config.contract_class.json, ...

────────────────────────────────────────────────────────────

[HIGH]     Incomplete account interface surface
   Detector:   account_interface_compliance
   Confidence: high
   Function:   <program>
   File:       satoru_MockAccount.contract_class.json

   Account-like function set detected, but interface compliance check
   failed: missing core account methods: __execute__, __validate__,
   is_valid_signature, supports_interface.

   Fingerprint: f7bb2a7bdc27a760

[MEDIUM]   felt252 arithmetic without range check
   Detector:   felt252_overflow
   Confidence: low
   Function:   satoru::config::config::Config::constructor
   File:       satoru_Config.contract_class.json

   Function 'Config::constructor': felt252_add at stmt 1569 performs
   felt252 arithmetic on user-controlled input without a proven range
   check. felt252 wraps silently modulo the field prime.

   Fingerprint: 623285b52ec8368f

────────────────────────────────────────────────────────────
  Summary: 0 critical, 1 high, 3 medium, 0 low, 0 info
```

### Clean scan (Piltover — Starknet appchain)

```
$ shdr detect ./piltover/target/dev/ --min-severity medium

shadowhare — piltover.sierra.json, piltover_appchain.contract_class.json, ...

────────────────────────────────────────────────────────────
  No findings.
────────────────────────────────────────────────────────────
  Summary: 0 critical, 0 high, 0 medium, 0 low, 0 info
```

---

## Understanding the Report

Every `shdr detect` run produces a structured report. This section explains every part of it so you can read, triage, and act on findings with confidence.

### Report structure

A human-format report has four sections, in order:

```
shadowhare — <artifact names>              ← Header
────────────────────────────────────────    ← Divider
[SEVERITY]  <title>                        ← Finding (repeated)
   Detector:   ...
   ...
────────────────────────────────────────    ← Divider
  Summary: 0 critical, 1 high, ...         ← Summary
  Compatibility: ...                       ← Compatibility info
  Warnings: ...                            ← Warnings (if any)
```

If there are no findings, the report shows `No findings.` between the dividers.

### Anatomy of a finding

Every finding contains these fields:

```
[HIGH]     Storage write without caller check         ← Severity + Title
   Detector:   write_without_caller_check             ← Detector ID
   Confidence: low                                    ← Confidence level
   Function:   MyContract::__wrapper__set_value        ← Function where issue lives
   File:       my_contract.contract_class.json        ← Artifact file
   Sierra stmt: 4397                                  ← Statement index in Sierra IR
   Source:     src/lib.cairo:42:5                      ← Source location (if debug info exists)

   Function 'set_value': writes to storage (first      ← Detailed description
   write at stmt 4397) without get_caller_address...    explaining the vulnerability

   Fingerprint: 09a859223861e02b                      ← Unique identifier for this finding
```

Here is what each field means:

**Severity + Title** — The colored tag (`[HIGH]`, `[MEDIUM]`, etc.) and a short human-readable summary of the issue. This is the first thing you read.

**Detector** — The unique ID of the detector that fired (e.g. `write_without_caller_check`). Use this to look up detailed documentation in [`docs/RULES.md`](docs/RULES.md), or to suppress it in config:

```bash
shdr detect ./target/dev/ --exclude write_without_caller_check
```

**Confidence** — How likely this is a true positive vs. a false positive. See [Confidence levels](#confidence-levels) below.

**Function** — The fully-qualified Sierra function name where the issue was found. Compiler-generated wrapper functions start with `__wrapper__` or `__external__` — these are serde wrappers the compiler emits around your actual functions.

**File** — The artifact path that was analyzed.

**Sierra stmt** — The index into the Sierra program's flat statement array where the issue occurs. This is the Sierra-level "line number". See [Sierra statement index](#sierra-statement-index) below.

**Source** — The original Cairo source location (`file:line:col`), shown only if the artifact contains debug info. Scarb builds include this by default; standalone compilation may not.

**Description** — A detailed explanation of what the detector found and why it matters. Often includes the specific operation (e.g. `felt252_add at stmt 1569`) and what is missing (e.g. "without a proven range check").

**Fingerprint** — A stable hex identifier for this exact finding at this exact location. See [Fingerprints](#fingerprints) below.

### Severity levels

Shadowhare assigns one of five severity levels to each detector. The severity is fixed per detector — every firing of `reentrancy` is always HIGH.

| Level | Color | Meaning | Action |
|-------|-------|---------|--------|
| **Critical** | Red bold | Exploitable vulnerability with direct fund loss | Fix immediately. Block deployment. |
| **High** | Red | Serious vulnerability that could lead to loss of funds, unauthorized access, or contract takeover | Fix before mainnet. Investigate every instance. |
| **Medium** | Yellow | Logic flaw, missing validation, or unsafe pattern that could be exploited under specific conditions | Fix before audit. Acceptable to baseline if mitigated elsewhere. |
| **Low** | Cyan | Best-practice violation, missing event, or code quality issue that doesn't directly threaten funds | Fix when convenient. Good for code hygiene. |
| **Info** | Dimmed | Informational observation — dead code, magic numbers, complexity metrics | Optional. Use `--min-severity low` to hide these (default). |

By default, `--min-severity low` hides Info findings. Use `--min-severity info` to see everything.

When piping to CI systems via SARIF, severities map to SARIF levels and CVSS-like scores:

| Shadowhare | SARIF level | Security severity score |
|------------|-------------|------------------------|
| Critical | `error` | 9.8 |
| High | `error` | 7.5 |
| Medium | `warning` | 5.0 |
| Low | `note` | 2.5 |
| Info | `note` | 0.0 |

### Confidence levels

Confidence reflects how likely the finding is a true positive. Each detector has a fixed confidence level.

| Level | Meaning | Typical false-positive rate |
|-------|---------|----------------------------|
| **High** | Strong evidence from multiple analysis passes (CFG + taint + call graph). Very likely a real issue. | < 5% |
| **Medium** | Good evidence from structural analysis. Usually correct but may fire on safe patterns the analyzer cannot fully resolve. | 5–20% |
| **Low** | Pattern match or heuristic. Flags suspicious code that may be intentional or mitigated elsewhere (e.g. in a caller function). | 20–50% |

### Triaging findings: the severity x confidence matrix

Not all findings deserve equal attention. Use this priority matrix:

| | Confidence: High | Confidence: Medium | Confidence: Low |
|---|---|---|---|
| **Critical/High severity** | **P0 — fix now.** Likely exploitable. | **P1 — investigate.** Read the description, check if mitigated. | **P2 — review.** Check manually; may be a false positive but the impact if real is severe. |
| **Medium severity** | **P1 — fix before audit.** | **P2 — review when possible.** | **P3 — baseline if mitigated.** |
| **Low/Info severity** | **P3 — fix for hygiene.** | **P4 — nice to fix.** | **P4 — informational.** |

A HIGH-severity, LOW-confidence finding (like `write_without_caller_check` with confidence: low) means: "if this is real, it's dangerous — but check manually because the analyzer isn't certain." This commonly fires on functions that enforce access control through an internal helper call that shadowhare can't trace across function boundaries yet.

### Sierra statement index

Sierra is Cairo's intermediate representation — a flat list of typed statements that the Starknet sequencer JITs into CASM. When shadowhare reports `Sierra stmt: 4397`, that means statement #4397 in the program's linear instruction array.

**What a statement is:** Each Sierra statement is either:
- An **Invocation** — a call to a library function (`libfunc`) like `felt252_add`, `storage_write`, `call_contract_syscall`, etc., with input variables and output branches
- A **Return** — returning variables from the current function

**How to use it:**
1. If debug info is present, shadowhare maps the statement back to source (shown as `Source: src/lib.cairo:42:5`)
2. If no debug info, use `shdr print ir-dump <artifact>` to see the raw IR and find statement 4397 manually
3. The statement index is deterministic for a given compilation — it won't change unless you recompile

**Why it matters:** The statement index pinpoints *exactly* where in the compiled code the vulnerable operation occurs. Two findings in the same function at different statements are distinct issues.

### Fingerprints

Every finding has a fingerprint like `09a859223861e02b`. This is the first 8 bytes (16 hex chars) of a SHA-256 hash computed from:

```
sha256("{detector_id}:{function_name}:{statement_idx}:{file_path}")
```

Fingerprints serve three purposes:

1. **Baseline tracking** — When you run `shdr update-baseline`, all current fingerprints are saved. On the next run with `--baseline`, only findings with *new* fingerprints (not in the baseline) are flagged. This lets CI pass on known issues while catching regressions.

2. **Suppression** — You can suppress a specific finding by its fingerprint in `Scarb.toml`:
   ```toml
   [[tool.shadowhare.suppress]]
   id = "write_without_caller_check"
   location_hash = "09a859223861e02b"
   ```

3. **Diff tracking** — `detect-diff` uses fingerprints to classify findings as new, resolved, or unchanged between two contract versions.

Fingerprints are stable across runs as long as the artifact doesn't change. Recompiling the contract may shift statement indices, which changes fingerprints.

### Compatibility and tier warnings

After the summary, the report shows compatibility information for each artifact:

```
Compatibility:
  - my_contract.contract_class.json: tier=Tier1 source=compiler_version

  - old_contract.contract_class.json: tier=Tier3 source=contract_class_version
    (degraded: contract_class_version='0.1.0' cannot be mapped to a semver)
```

**What the tiers mean for your results:**

| Tier | Cairo version | What it means |
|------|---------------|---------------|
| **Tier 1** | `~2.16` (current) | Full support. All 71 detectors run. Results are CI-quality — you can trust them to block deployments. |
| **Tier 2** | `~2.15` (previous stable) | Full detector support. Fully tested. Minor IR differences from Tier 1 are handled. |
| **Tier 3** | `~2.14` and older 2.x | Best-effort. Most detectors run but some may skip if the IR structure is too different. Results are directionally correct but review manually. |
| **Unsupported** | Cairo 1.x | Rejected entirely. Shadowhare only analyzes Sierra IR from Cairo 2.x+. |

**Metadata source** tells you how shadowhare determined the tier:
- `compiler_version` — extracted from `debug_info.compiler_version` (most reliable)
- `sierra_version` — extracted from `sierra_version` field
- `contract_class_version` — extracted from `contract_class_version` field (least specific)
- `unavailable` — no version metadata found (defaults to Tier 3)

**When you see `(degraded: ...)`** — the version string was found but couldn't be parsed into a semver range, so shadowhare fell back to Tier 3 best-effort mode. This is common with older artifacts.

**The `--strict` flag** makes shadowhare exit with code 2 if any artifact has degraded compatibility. Use this in CI when you want to guarantee Tier 1/2 analysis quality.

### The summary line

```
Summary: 0 critical, 1 high, 3 medium, 0 low, 0 info
```

This counts findings *after* filtering by `--min-severity`, `--exclude`, suppressions, and baseline. It reflects exactly what was shown in the report.

The process exit code is derived from the summary:
- **Exit 0** — zero findings (or zero *new* findings if `--fail-on-new-only`)
- **Exit 1** — one or more findings at or above the severity threshold
- **Exit 2** — runtime error (bad file path, parse failure, `--strict` with degraded tier)

### Warnings section

```
Warnings:
  ⚠  contract_class_version='0.1.0' cannot be mapped to a semver
  ⚠  detector 'pragma_stale_price' skipped: requires Tier2, artifact is Tier3
```

Warnings are non-fatal issues that didn't prevent analysis but may affect result quality. Common warnings:
- **Compatibility degradation** — version couldn't be determined precisely
- **Detector skipped** — a detector's minimum tier requirement wasn't met
- **Plugin failure** — an external plugin crashed or returned invalid output
- **Missing debug info** — a source-aware detector couldn't run without debug info

### Output formats

Shadowhare supports three output formats via `--format`:

**`human` (default)** — Colored terminal output as described above. Best for interactive use.

**`json`** — Machine-readable JSON with schema version `1.0.0`:

```json
{
  "schema_version": "1.0.0",
  "generated_at": 1710000000,
  "analyzer_version": "1.0.0",
  "sources": ["my_contract.contract_class.json"],
  "artifacts": [{
    "source": "my_contract.contract_class.json",
    "compatibility_tier": "Tier1",
    "metadata_source": "compiler_version",
    "degraded_reason": null
  }],
  "findings": [{
    "detector_id": "reentrancy",
    "severity": "high",
    "confidence": "high",
    "title": "Reentrancy vulnerability",
    "description": "Function 'withdraw': storage read at stmt 100...",
    "location": {
      "file": "my_contract.contract_class.json",
      "function": "MyContract::withdraw",
      "statement_idx": 100,
      "line": 42,
      "col": 5
    },
    "fingerprint": "a1b2c3d4e5f6a7b8"
  }],
  "warnings": [{"kind": "compatibility", "message": "..."}],
  "summary": {
    "total": 1, "critical": 0, "high": 1,
    "medium": 0, "low": 0, "info": 0
  }
}
```

Use JSON when you want to programmatically parse results, feed into dashboards, or integrate with custom tooling.

**`sarif`** — [SARIF 2.1.0](https://sarifweb.azurewebsites.net/) for GitHub Code Scanning and other SARIF-compatible tools. Upload directly to GitHub:

```yaml
- name: Upload SARIF
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: results.sarif
```

SARIF output includes `security-severity` scores (CVSS-style) and `precision` levels so GitHub's security tab can sort and filter findings correctly.

### Reading a detect-diff report

`shdr detect-diff` compares two contract versions and classifies every finding:

```
Shadowhare Diff Report

Left sources:
  - ./v1/target/dev/my_contract.contract_class.json
Right sources:
  - ./v2/target/dev/my_contract.contract_class.json

Summary: new=2 resolved=1 unchanged=5
  New by severity:     critical=0 high=1 medium=1 low=0 info=0
  Resolved by severity: critical=0 high=0 medium=0 low=1 info=0

New findings:
  - [HIGH] reentrancy (Reentrancy vulnerability)
    at my_contract.contract_class.json :: MyContract::withdraw :: stmt 200
    fp=a1b2c3d4e5f6a7b8

Resolved findings:
  - [LOW] missing_event_emission (State change without event emission)
    at my_contract.contract_class.json :: MyContract::set_owner :: stmt 50
    fp=f0e1d2c3b4a59687

Unchanged fingerprints:
  - 1122334455667788
  - aabbccddeeff0011
  ...
```

| Category | Meaning |
|----------|---------|
| **New** | Finding exists in v2 but not in v1. This is a regression — the upgrade introduced a new issue. |
| **Resolved** | Finding existed in v1 but not in v2. The upgrade fixed this issue. |
| **Unchanged** | Finding exists in both versions (same fingerprint). Pre-existing, not caused by the upgrade. |

Use `--fail-on-new-severity high` to make CI fail only when the upgrade introduces new HIGH+ findings:

```bash
shdr detect-diff --left ./v1/target/dev/ --right ./v2/target/dev/ \
  --fail-on-new-severity high
# Exit 0 if no new high/critical findings, exit 1 otherwise
```

### Reading baseline-filtered output

When you run with `--baseline .shadowhare-baseline.json --fail-on-new-only`, the report only shows findings whose fingerprints are **not** in the baseline file. This means:

- **Shown findings** = newly introduced since the baseline was created
- **Hidden findings** = known issues already captured in the baseline

The summary reflects only the shown (new) findings. Exit code 1 triggers only if there are new findings.

To refresh the baseline after you've triaged or fixed findings:

```bash
shdr update-baseline ./target/dev/ --baseline .shadowhare-baseline.json
```

The baseline file is simple JSON — an array of fingerprint strings:

```json
{
  "schema_version": "1.0.0",
  "fingerprints": ["09a859223861e02b", "11862d120c9d7d4d", "..."]
}
```

### Structural printers

Beyond security detection, `shdr print` provides 7 structural analysis printers:

| Printer | Command | What it shows |
|---------|---------|---------------|
| **summary** | `shdr print summary <PATH>` | Per-artifact overview: function counts (external, view, L1 handler, constructor, internal), total statements, call graph edge count, compatibility tier |
| **callgraph** | `shdr print callgraph <PATH>` | Function call graph. Use `--format dot` to generate Graphviz output: `shdr print callgraph <PATH> --format dot \| dot -Tpng -o callgraph.png` |
| **attack-surface** | `shdr print attack-surface <PATH>` | Maps every entrypoint to reachable sinks (storage writes, external calls, library calls, L2→L1 messages, upgrades, deploys). Shows what an attacker can reach from each external function. |
| **storage-layout** | `shdr print storage-layout <PATH>` | Storage slot analysis — what state variables exist and how they're organized |
| **data-dependence** | `shdr print data-dependence <PATH>` | Variable data flow and dependency chains through the program |
| **function-signatures** | `shdr print function-signatures <PATH>` | Function parameter and return types for every function |
| **ir-dump** | `shdr print ir-dump <PATH>` | Raw Sierra IR dump — every statement with index, useful for manually inspecting `Sierra stmt` references from findings |

All printers support `--format human` (default) and `--format json` (schema version 1.0). The callgraph printer additionally supports `--format dot` for Graphviz.

### External plugins

You can extend shadowhare with custom detectors via the `--plugin` flag:

```bash
shdr detect ./target/dev/ --plugin ./my-custom-detector
```

**Protocol:** Shadowhare invokes your plugin as `<executable> <artifact_path>`. Your plugin must:
1. Read the Sierra artifact from the given path
2. Run its analysis
3. Print JSON to stdout (exit 0 on success, non-zero on failure)

**Output format** — any of these:
```json
[{"detector_id": "my_check", "severity": "high", "confidence": "medium",
  "title": "Issue found", "description": "Details...",
  "location": {"file": "contract.json", "function": "fn_name",
               "statement_idx": 42, "line": null, "col": null}}]
```
or wrapped: `{"findings": [...]}`

Plugin findings go through the same filtering pipeline (severity threshold, suppressions, exclude list) as built-in detectors.

---

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         Sierra Artifacts         │
                    │  .sierra.json  .contract_class   │
                    └────────────────┬────────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │           Loader              │
                    │  SierraLoader + VersionNeg.   │
                    │  Contract class enrichment    │
                    └───────────────┬───────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │        Internal IR            │
                    │  ProgramIR · TypeRegistry     │
                    │  FunctionClassifier · OZ      │
                    │  component detection          │
                    └───────────────┬───────────────┘
                                    │
            ┌───────────────────────┼───────────────────────┐
            │                       │                       │
  ┌─────────▼─────────┐  ┌─────────▼─────────┐  ┌─────────▼─────────┐
  │    CFG Engine      │  │   Taint Engine    │  │   Call Graph      │
  │  2-phase build     │  │  RPO worklist     │  │  Function         │
  │  dominator tree    │  │  source→sink      │  │  summaries        │
  │  natural loops     │  │  sanitizer-aware  │  │  reachability     │
  └─────────┬─────────┘  └─────────┬─────────┘  └─────────┬─────────┘
            │                       │                       │
            └───────────────────────┼───────────────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │      71 Detectors (parallel)  │
                    │  21 High · 26 Med · 16 Low    │
                    │  8 Info · deterministic order  │
                    └───────────────┬───────────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
    ┌─────────▼───────┐  ┌─────────▼───────┐  ┌─────────▼───────┐
    │     Human       │  │      JSON       │  │     SARIF       │
    │  terminal report│  │  versioned API  │  │  2.1.0 for CI   │
    └─────────────────┘  └─────────────────┘  └─────────────────┘
```

---

## Detector Overview

### High Severity (21)

| Detector | Description |
|----------|-------------|
| `reentrancy` | Storage read → external call → storage write pattern |
| `unprotected_upgrade` | `replace_class_syscall` without owner check |
| `unchecked_l1_handler` | L1 handler missing `from_address` validation |
| `controlled_library_call` | Library call with user-controlled class hash |
| `signature_replay` | Signature verification without nonce check |
| `arbitrary_token_transfer` | Token transfer with attacker-controlled parameters |
| `write_without_caller_check` | Storage write in external function without caller validation |
| `oracle_price_manipulation` | External call result stored without validation |
| `deploy_syscall_tainted_class_hash` | Deploy with user-controlled class hash |
| `initializer_replay_or_missing_guard` | Initializer without one-time guard |
| `missing_nonce_validation` | `__execute__` without nonce increment |
| `account_interface_compliance` | Incomplete SRC6 account interface |
| `account_validate_forbidden_syscalls` | Side-effectful syscalls in validation |
| `account_execute_missing_v0_block` | Missing tx-version guard in `__execute__` |
| `unchecked_ecrecover` | EC recovery without validation |
| `rtlo` | Right-to-left override character injection |
| `u256_underflow` | Unchecked u256 subtraction |
| `l1_handler_payload_to_storage` | L1 payload written to storage without sanitization |
| `l1_handler_unchecked_selector` | L1 handler without selector validation |
| `l2_to_l1_tainted_destination` | L2→L1 message with tainted destination |
| `l2_to_l1_unverified_amount` | L2→L1 message with unverified amount |

### Medium Severity (26)

| Detector | Description |
|----------|-------------|
| `felt252_overflow` | felt252 arithmetic without range check |
| `unchecked_integer_overflow` | Integer arithmetic with silent overflow discard |
| `integer_truncation` | u256→felt252 without high-word bounds check |
| `unchecked_address_cast` | Fallible address cast with unhandled failure |
| `unchecked_array_access` | Array access without bounds checking |
| `tx_origin_auth` | Authentication using transaction origin |
| `divide_before_multiply` | Division before multiplication (precision loss) |
| `weak_prng` | Weak pseudo-random number generation |
| `hardcoded_address` | Hardcoded contract/wallet addresses |
| `block_timestamp_dependence` | Block timestamp used for critical logic |
| `unchecked_transfer` | Token transfer without return value check |
| `tainted_storage_key` | User-controlled storage key |
| `gas_griefing` | Unbounded loop callable by external users |
| `view_state_modification` | View function modifying state |
| `uninitialized_storage_read` | Reading storage before initialization |
| `multiple_external_calls` | Multiple external calls in single function |
| `tautological_compare` | Always-true/false comparison |
| `tautology` | Tautological expression |
| `l1_handler_unchecked_amount` | L1 handler with unchecked amount |
| `l2_to_l1_double_send` | Duplicate L2→L1 messages |
| `pyth_*` (3) | Pyth oracle misuse patterns |
| `pragma_*` (3) | Pragma oracle misuse patterns |

### Low Severity (16)

| Detector | Description |
|----------|-------------|
| `missing_event_emission` | State-modifying function emits no event |
| `missing_events_access_control` | Privileged state mutation with no event |
| `missing_events_arithmetic` | Arithmetic-driven storage update with no event |
| `missing_pausable` | No pause mechanism in state-modifying contract |
| `missing_zero_address_check` | Address input used without zero-address validation |
| `incorrect_erc20_interface` | Incomplete or inconsistent ERC20 interface |
| `incorrect_erc721_interface` | Incomplete or inconsistent ERC721 interface |
| `event_before_state_change` | Event emitted before the state change it describes |
| `calls_loop` | External/library call inside a loop body |
| `write_after_write` | Redundant storage writes without intervening read |
| `reentrancy_events` | Event emitted between external call and storage write |
| `unused_return` | Function return value silently discarded |
| `unchecked_l1_message` | L1 message sent without caller verification |
| `shadowing_builtin` | Entrypoint name collides with Cairo builtin |
| `shadowing_local` | Adjacent symbol segments suggest local name shadowing |
| `shadowing_state` | Function name collides with state/type name |

### Info (8)

| Detector | Description |
|----------|-------------|
| `dead_code` | Function never called and not an entry point |
| `magic_numbers` | Large numeric literal without a named constant |
| `costly_loop` | Storage access inside a loop |
| `cache_array_length` | Array length repeatedly queried inside a loop |
| `boolean_equality` | Boolean compared to literal `true`/`false` |
| `unindexed_event` | Event uses empty keys/index set |
| `unused_state` | Storage value loaded but never used |
| `excessive_function_complexity` | High cyclomatic complexity — hard to test and review |

Full detector documentation with examples: [`docs/RULES.md`](docs/RULES.md)

---

## CLI Reference

```bash
# Core commands
shdr detect <PATH...> [options]        # Run security analysis
shdr detect-diff --left <V1> --right <V2>  # Compare two versions
shdr print <PRINTER> <PATH...>         # Structural analysis
shdr update-baseline <PATH...>         # Snapshot current findings
shdr list-detectors                    # Show all detectors
```

### Global flags

| Flag | Description |
|------|-------------|
| `-v, --verbose` | Enable debug-level logging (`RUST_LOG=shadowhare=debug`) |
| `-q, --quiet` | Suppress all output except errors (`RUST_LOG=shadowhare=error`) |
| `--no-color` | Disable colored output (also respects `NO_COLOR` env var) |
| `-V, --version` | Print shadowhare version and exit |

### `detect` options

| Flag | Description | Default |
|------|-------------|---------|
| `--format <human\|json\|sarif>` | Output format | `human` |
| `--min-severity <info\|low\|medium\|high>` | Severity threshold | `low` |
| `--detectors <id1,id2,...>` | Run only these detectors | all |
| `--exclude <id1,id2,...>` | Skip these detectors | none |
| `--baseline <path>` | Baseline file for diffing | none |
| `--fail-on-new-only` | Exit 1 only for new findings | off |
| `--strict` | Fail on degraded analysis | off |
| `--manifest <Scarb.toml>` | Read project config | auto-discover |
| `--plugin <exe>` | External detector plugin (repeatable for multiple plugins) | none |

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | No findings (or no new findings with `--fail-on-new-only`) |
| `1` | Findings detected |
| `2` | Runtime error |

### `detect-diff` options

| Flag | Description | Default |
|------|-------------|---------|
| `--left <PATH...>` | Left-side (old version) artifacts | required |
| `--right <PATH...>` | Right-side (new version) artifacts | required |
| `--format <human\|json>` | Output format | `human` |
| `--min-severity <info\|low\|medium\|high>` | Severity threshold | `low` |
| `--detectors <id1,id2,...>` | Run only these detectors | all |
| `--exclude <id1,id2,...>` | Skip these detectors | none |
| `--fail-on-new-severity <level>` | Exit 1 only if new findings reach this severity | any new finding |
| `--strict` | Fail on degraded analysis | off |
| `--manifest <Scarb.toml>` | Read project config | auto-discover |
| `--plugin <exe>` | External detector plugin | none |

### `print` options

```bash
shdr print <PRINTER> <PATH...> [--format <human|json|dot>]
```

| Printer | What it shows |
|---------|---------------|
| `summary` | Per-artifact overview: function counts, statement count, call graph edges, compatibility tier |
| `callgraph` | Function call graph. Supports `--format dot` for Graphviz output |
| `attack-surface` | Entrypoint-to-sink reachability map (storage writes, external calls, library calls, L2→L1 messages, upgrades, deploys) |
| `storage-layout` | Storage slot analysis — state variables and their organization |
| `data-dependence` | Variable data flow and dependency chains |
| `function-signatures` | Parameter and return types for every function |
| `ir-dump` | Raw Sierra IR — every statement with its index, useful for tracing `Sierra stmt` references |

| Flag | Description | Default |
|------|-------------|---------|
| `--format <human\|json\|dot>` | Output format (`dot` only for callgraph) | `human` |

### `update-baseline` options

```bash
shdr update-baseline <PATH...> [--baseline <FILE>]
```

Runs all detectors on the given artifacts and saves every finding's fingerprint to the baseline file. On subsequent `detect` runs with `--baseline`, only findings *not* in this file trigger exit code 1.

| Flag | Description | Default |
|------|-------------|---------|
| `--baseline <path>` | Path to baseline file to create/overwrite | `.shadowhare-baseline.json` |

### `list-detectors`

```bash
shdr list-detectors
```

Prints a table of all 71 built-in detectors with four columns:

| Column | Description |
|--------|-------------|
| `ID` | Unique detector identifier (use with `--detectors` or `--exclude`) |
| `SEVERITY` | Fixed severity level: critical, high, medium, low, or info |
| `CONFIDENCE` | Fixed confidence level: high, medium, or low |
| `Description` | One-line explanation of what the detector checks |

---

## CI/CD Integration

### GitHub Actions

```yaml
- name: Build Cairo contracts
  run: scarb build

- name: Security scan
  run: |
    cargo install shadowhare
    shdr detect ./target/dev/ --format sarif --min-severity medium \
      > results.sarif

- name: Upload SARIF
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: results.sarif
```

### Baseline workflow (suppress known findings)

```bash
# Create baseline from current state
shdr update-baseline ./target/dev/ --baseline .shadowhare-baseline.json

# In CI: only fail on NEW findings
shdr detect ./target/dev/ --baseline .shadowhare-baseline.json --fail-on-new-only
```

### Upgrade safety check

```bash
# Compare v1 vs v2 — fail if new high-severity findings appear
shdr detect-diff --left ./v1/target/dev/ --right ./v2/target/dev/ \
  --fail-on-new-severity high
```

---

## Configuration via Scarb.toml

```toml
[tool.shadowhare]
detectors = ["all"]
exclude = ["dead_code"]
severity_threshold = "medium"
baseline = ".shadowhare-baseline.json"
strict = false
plugins = ["./target/debug/my-plugin"]

[[tool.shadowhare.suppress]]
id = "reentrancy"
location_hash = "a1b2c3d4"  # optional: omit to suppress all from this detector
```

CLI flags always override `Scarb.toml` values.

---

## Compatibility

| Cairo Compiler | Support Tier | Detector coverage | CI-safe? |
|---------------|--------------|-------------------|----------|
| `~2.16` | Tier 1 (full support) | All 71 detectors | Yes |
| `~2.15` | Tier 2 (supported) | All 71 detectors | Yes |
| `~2.14` and older 2.x | Tier 3 (best-effort) | Most detectors; some skip if IR differs too much | Review manually |
| Cairo 1.x | Unsupported | None — rejected at load time | N/A |

Artifacts without version metadata are analyzed in Tier 3 best-effort mode with a warning. Use `--strict` to reject degraded artifacts in CI.

---

## Building from Source

**Prerequisites:** Rust 1.75+

```bash
git clone https://github.com/br0wnD3v/shadowhare.git
cd shadowhare
cargo build --release

# Run tests
cargo test

# Run clippy
cargo clippy --all-targets -- -D warnings

```

---

## License

Licensed under either of:

- [MIT license](LICENSE-MIT)
- [Apache License, Version 2.0](LICENSE-APACHE)

at your option.
