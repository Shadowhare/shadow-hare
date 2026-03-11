# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-11

### Added
- 5-layer architecture: loader, IR, analysis, detectors, output
- 71 security detectors (21 High, 26 Medium, 16 Low, 8 Info) covering OWASP Smart Contract Top 10
- CFG-based taint analysis with configurable sanitizer lists
- Dominator-tree guard verification for access control patterns
- Inter-procedural analysis via CallGraph + FunctionSummaries
- OpenZeppelin component awareness (Ownable, AccessControl, Upgradeable, Pausable, ReentrancyGuard)
- Storage layout extraction from `storage_base_address_const` patterns
- Output formats: Human, JSON (versioned), SARIF 2.1.0
- Baseline diffing for CI integration
- External plugin support via JSON protocol
- Compatibility matrix for Sierra version negotiation (Tier1 ~2.16, Tier2 ~2.15, Tier3 ~2.14)
- Criterion benchmarks for loader, IR, CFG, detectors, and full pipeline
- Docker support via multi-stage Dockerfile
- GitHub Actions CI (stable + MSRV 1.75) and multi-platform release workflows
- `scarb-shdr` / `scarb-shadowhare` Scarb plugin binaries
- Pragma oracle detector suite (freshness, aggregation, source count)
- Gas griefing detection for unbounded loop patterns
- Magic number and function complexity informational detectors
