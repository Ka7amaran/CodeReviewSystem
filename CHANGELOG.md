# Changelog

All notable changes to the `android-review` plugin will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semver](https://semver.org/).

## [1.1.1] — 2026-04-30

### Changed

- Sync plugin description across `plugin.json` and `marketplace.json`.
  Both now read: "Automated code review for Android projects.
  Orchestrator + 3 parallel sub-agents reading declarative markdown
  rules."

## [1.1.0] — 2026-04-30

### Added

- New slash command `/android-review:android-review-init` —
  initializes `.claude/CLAUDE.md` scaffold for the current Android
  project. Auto-fills `project-id`, `applicationId`, `namespace`,
  `minSdk`, `targetSdk` from `app/build.gradle(.kts)`. Leaves
  placeholder TODOs for `critical-classes` and `sensitive-files` for
  the user to fill in. Also appends `.claude/reports/` to the
  project's `.gitignore`.
- Refuses to overwrite if `.claude/CLAUDE.md` already exists.
- README: full Quickstart section walking through init → fill TODOs →
  full review.

### Changed

- README: command list now uses fully-qualified names
  (`/android-review:android-review` etc.).

## [1.0.1] — 2026-04-30

### Fixed

- **Portability:** plugin root is now auto-detected at runtime via
  `ls -td "$HOME/.claude/plugins/cache/android-review-marketplace/android-review/"*/ | head -1`
  in all 4 slash commands. Replaces the previous hardcoded
  `/Users/mac/CodeReviewSystem` path that broke on any other machine.
  The plugin is now installable on any Mac/Linux via `github:Ka7amaran/CodeReviewSystem`.

## [1.0.0] — 2026-04-30

### Added

- Initial MVP release.
- Slash command `/android-review` (orchestration runs in command body —
  Claude Code 2.1.x forbids `Task` from inside a sub-agent).
- Three standalone sub-agent commands: `/android-review-style`,
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
- Auto-detect fallback for `critical-classes` when CLAUDE.md is missing.
- Cross-cutting check `cross/exported-component-not-keep` (FQCN
  canonicalization through manifest's `package=`).
- Dual-format report output: `<project-id>-android-review.md` and
  `<project-id>-android-review.gdoc.txt` saved to
  `.claude/reports/` with stable name + `archive/` history.
- Compact terminal summary (table + verdict + counts + saved-paths);
  full report stays in saved files.
- Marketplace manifest (`.claude-plugin/marketplace.json`) for local
  install.

### Notes

- Plugin root path is hardcoded to `/Users/mac/CodeReviewSystem` for
  local install. Replace with the actual path or revisit with a
  marketplace-source mechanism when published to GitHub.
- Smoke-test pass on 2026-04-30 against `Juice-Master-Factory` and
  `Joker-Speed-Seven`: S1 ✓, S2 ✓, S3 ✓, S4 ✓, S5 ⚠️ (graceful
  fallback design verified architecturally; full `missing ⚠️` header
  re-run skipped — see `docs/smoke-test.md`).
