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

## Use

```
cd ~/StudioProjects/<your-android-project>
claude
/android-review
```

## Per-project setup

Each Android project needs a `.claude/CLAUDE.md` declaring its `project-id`,
`critical-classes`, and `sensitive-files`. See template:
`docs/project-claude-md-template.md`.

## Commands

- `/android-review` — Orchestrator. Runs all three sub-agents in parallel,
  merges results, and writes the final report to `.claude/reports/`.
- `/android-review-style` — Sub-agent: checks Kotlin naming conventions,
  Compose stability, and Hilt injection patterns.
- `/android-review-security` — Sub-agent: audits Manifest permissions,
  cleartext traffic, hardcoded secrets, and exported components.
- `/android-review-obfuscation` — Sub-agent: inspects ProGuard rules, `-keep`
  coverage for critical classes, and plain-string seed keys.

## Adding rules

See `docs/how-to-add-a-rule.md`.

## Architecture

See `docs/specs/2026-04-29-android-review-system-design.md`.
