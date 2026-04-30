# android-review

## What this is

A Claude Code plugin that automates code review for Android projects built on
Kotlin, Jetpack Compose, and Hilt. It formalises a shared checklist — style,
security, and obfuscation — as machine-readable rules executed by Claude Code
agents, producing a consistent report you can paste into Google Docs for sharing.
The review is purely static; no build, no APK analysis.

## Install

In any Claude Code session:

```
/plugin marketplace add github:Ka7amaran/CodeReviewSystem
/plugin install android-review@android-review-marketplace
```

The plugin will be cached under
`~/.claude/plugins/cache/android-review-marketplace/android-review/<version>/`.
The slash commands auto-detect that path at runtime — no manual
configuration needed.

## Quickstart (per Android project)

Run these once per project, in order:

### 1. Initialize CLAUDE.md scaffold

```
cd ~/StudioProjects/<your-android-project>
claude
/android-review:android-review-init
```

This creates `.claude/CLAUDE.md` with:
- `project-id`, `applicationId`, `namespace`, `minSdk`, `targetSdk` —
  auto-filled from `app/build.gradle(.kts)`.
- `critical-classes`, `sensitive-files` — left as TODO comments.
- `accepted-risks`, `rule-overrides` — left empty with explainer comments.

It also appends `.claude/reports/` to your project's `.gitignore`.

If `.claude/CLAUDE.md` already exists, this command refuses to
overwrite it and exits.

### 2. Fill the TODO sections

Open `.claude/CLAUDE.md` and replace the TODO blocks with your
project-specific values:

- **`critical-classes`** — package globs whose classes must be covered
  by `-keep` rules (crypto, JSON DTOs, Hilt entry points). The
  obfuscation auditor uses this to flag missing keep coverage.
- **`sensitive-files`** — file globs where the security auditor
  should look harder for hardcoded secrets, junk-char obfuscation,
  plain-string seeds.

Commit `.claude/CLAUDE.md` to the project repo — it's configuration,
not local state.

### 3. Run the full review

```
/android-review:android-review
```

You get a compact terminal summary plus two saved files:
`.claude/reports/<project-id>-android-review.md` (Markdown) and
`.claude/reports/<project-id>-android-review.gdoc.txt`
(Google-Docs-friendly).

## Commands

- `/android-review:android-review-init` — Run ONCE per project. Creates
  `.claude/CLAUDE.md` scaffold from auto-detected gradle values; appends
  `.claude/reports/` to `.gitignore`. Refuses to overwrite if file exists.
- `/android-review:android-review` — Full review. Runs all three
  sub-agents in parallel, performs cross-cutting analysis, writes the
  final report to `.claude/reports/`, prints a compact summary.
- `/android-review:android-review-style` — Sub-agent only: Kotlin
  naming conventions, Compose stability, Hilt injection patterns.
- `/android-review:android-review-security` — Sub-agent only: Manifest
  permissions, cleartext traffic, hardcoded secrets, exported components.
- `/android-review:android-review-obfuscation` — Sub-agent only: ProGuard
  rules, `-keep` coverage for critical classes, plain-string seed keys.

## Adding rules

See `docs/how-to-add-a-rule.md`.

## Architecture

See `docs/specs/2026-04-29-android-review-system-design.md`.
