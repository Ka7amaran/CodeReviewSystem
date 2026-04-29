# Manual smoke-test plan

Run before every release of the plugin (any non-patch bump).
Total time: ~10 minutes.

## Prerequisites

- Plugin is installed locally (or symlinked to a marketplace).
- `~/StudioProjects/Juice-Master-Factory` and
  `~/StudioProjects/Joker-Speed-Seven` exist with `.claude/CLAUDE.md`
  populated (see `docs/project-claude-md-template.md`).

## Scenario S1 — Juice full run

```bash
cd ~/StudioProjects/Juice-Master-Factory
claude
/android-review
```

Expected:
- `**Verdict:** NOT READY`
- ≥5 errors. Must include at minimum:
  - `security/no-cleartext-traffic`
  - `obfuscation/proguard-rules-not-empty`
  - `obfuscation/crypto-classes-keep-rules-present` (because no -keep
    is present despite minify=true)
- A cross-cutting finding linking exported MainActivity to absent -keep.
- Two report files exist in `.claude/reports/`: `.md` and `.gdoc.txt`.

## Scenario S2 — Joker full run

```bash
cd ~/StudioProjects/Joker-Speed-Seven
claude
/android-review
```

Expected:
- `**Verdict:** NOT READY`
- ≥4 errors. Must include:
  - `obfuscation/proguard-rules-not-empty`
  - `obfuscation/crypto-classes-keep-rules-present`
  - `security/no-hardcoded-secrets` (USER_SEED in
    `settings/crypto/UserHelpManager.kt`)
  - `obfuscation/seed-keys-not-plain-string` (same finding from a
    different angle)
- Two report files exist in `.claude/reports/`.

## Scenario S3 — Targeted obfuscation pass

```bash
cd ~/StudioProjects/Juice-Master-Factory
claude
/android-review-obfuscation
```

Expected:
- Wall-clock < 3 seconds.
- Output is the obfuscation section only, no orchestrator headers.
- No file written to `.claude/reports/`.

## Scenario S4 — Not in an Android project

```bash
cd /tmp
claude
/android-review
```

Expected:
- The orchestrator immediately prints:
  `This is not an Android project root. Expected app/build.gradle(.kts) — not found.`
- No report file is written.

## Scenario S5 — CLAUDE.md missing

```bash
cd ~/StudioProjects/Juice-Master-Factory
mv .claude/CLAUDE.md .claude/CLAUDE.md.bak
claude
/android-review
```

Expected:
- Run completes without error.
- Report header shows `**CLAUDE.md:** missing ⚠️`.
- Obfuscation auditor reports auto-detected critical classes.
- More INFO findings overall (less filtering of style rule applies-to).

After: `mv .claude/CLAUDE.md.bak .claude/CLAUDE.md`.

## Recording results

After each release, append a short note to `CHANGELOG.md` under the
release entry: "Smoke-test passed: S1 ✓ S2 ✓ S3 ✓ S4 ✓ S5 ✓".

If any scenario fails, fix BEFORE tagging the release. Do not mark
"known issue" — silent regressions are exactly what this manual gate
exists to prevent.
