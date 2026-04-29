# Changelog

All notable changes to the `android-review` plugin will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semver](https://semver.org/).

## [1.0.0] — 2026-04-29

### Added

- Initial MVP release.
- Orchestrator command `/android-review` with cross-cutting analysis.
- Three sub-agent commands: `/android-review-style`,
  `/android-review-security`, `/android-review-obfuscation`.
- Nine starter rules (3 per category):
  - **style**: kotlin-naming-conventions, compose-stable-parameters,
    hilt-no-field-injection.
  - **security**: no-cleartext-traffic, no-hardcoded-secrets,
    exported-component-without-permission.
  - **obfuscation**: proguard-rules-not-empty,
    crypto-classes-keep-rules-present, seed-keys-not-plain-string.
- Project-level `.claude/CLAUDE.md` template with `project-id`,
  `expected-values`, `critical-classes`, `sensitive-files`,
  `accepted-risks` sections (R3 `rule-overrides` placeholder reserved).
- Dual-format report output: `<project-id>-android-review.md` and
  `<project-id>-android-review.gdoc.txt` saved to
  `.claude/reports/` with stable name + `archive/` history.
- Read-only sandbox: plugin denies `Edit`, `Write`, mutating shells.
