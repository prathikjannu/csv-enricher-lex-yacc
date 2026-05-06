# Changelog

All notable changes to this project will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/) — `MAJOR.MINOR.PATCH`.

---

## [1.0.0] — 2026-05-06

### Added
- **Phase 1** — standalone CSV parser (Flex + Bison): tokenises any CSV and prints rows
- **Phase 2** — standalone config rule parser: parses `if <field> <op> <value> set <col> <label>` rules
- **Phase 3** — combined streaming enricher: two parsers in one binary using Flex/Bison prefix renaming
- Streaming row-by-row CSV processing — O(1) memory regardless of file size (tested: 100k rows in < 100ms)
- Supported operators: `>`, `<`, `>=`, `<=`, `==`, `!=`
- Exit codes: `0` success, `1` hard error (missing file / no rules), `2` partial (unclassified rows)
- `--version` flag in the enricher binary
- `test.sh` — 23 automated tests
- `deploy.sh` — production install script (Linux/macOS)
- `scripts/run_enricher.sh` — cron wrapper with append-only error log, duplicate-skip, auto-cleanup
- Windows support via WSL2 and MSYS2 (documented in README)

---

## Versioning Policy

| Change type | Version bump | Example |
|---|---|---|
| New rule operators, new flags | `MINOR` — `1.1.0` | Add `contains` operator |
| Bug fixes, performance | `PATCH` — `1.0.1` | Fix edge case in quoted CSV |
| Breaking grammar/config format | `MAJOR` — `2.0.0` | Change rule syntax |
