# Manual smoke-test plan (v2.0)

Run before every release of the plugin (any non-patch bump).
Total time: ~10 minutes.

## Prerequisites

- Plugin installed locally (`/plugin marketplace add Ka7amaran/CodeReviewSystem`
  + `/plugin install`).
- At least one real team Android project at `~/StudioProjects/<project>/`.

## Scenario S1 — Init on a fresh project

Pick any project that doesn't yet have `.claude/CLAUDE.md`:

```
cd ~/StudioProjects/<some-project>
claude
/android-review-init
```

Expected:
- `.claude/CLAUDE.md` created with 5 sections.
- `project-type`, `landing-mechanism`, `backend-domain` auto-filled
  (the latter when uniquely detectable).
- `redirect-method` and `accepted-deviations` are TODO.
- `.claude/reports/` appended to project's `.gitignore`.
- Onboarding message printed with next-step hint.

## Scenario S2 — Refusal on existing CLAUDE.md

Re-run `/android-review-init` in the same project:

Expected:
- Print `.claude/CLAUDE.md already exists — nothing to do.`
- No file modifications.

## Scenario S3 — Full review on with-attribution project

Edit `.claude/CLAUDE.md` from S1 to set `redirect-method: 7.1`. Then:

```
/android-review
```

Expected:
- 3 sub-agent calls visible (no — single dispatch, just one
  `functional-validator` call).
- Compact summary in terminal:
  - Header with project-type/landing-mechanism/redirect-method.
  - Verdict (`✅ ГОТОВО` / `⚠️ З ЗАСТЕРЕЖЕННЯМИ` / `🔴 НЕ ГОТОВО`).
  - Counts per severity.
  - Saved-path.
- Saved file `.claude/reports/<project-id>-android-review.md` exists,
  has the full report with all sections including "Перевірені
  інваріанти" pass list.

## Scenario S4 — Hard-abort on non-Android directory

```
cd /tmp
claude
/android-review
```

Expected: exact two-line English abort message, no further tool calls.

## Scenario S5 — No-attribution project

Edit `.claude/CLAUDE.md` to set `project-type: no-attribution`. Run
`/android-review`. Expected: all `flow/*` rules in "Пропущені
перевірки" with reason
`project-type: with-attribution required, current: no-attribution`.

## Recording results

After release, append to `CHANGELOG.md` under the release entry:
"Smoke-test passed: S1 ✓ S2 ✓ S3 ✓ S4 ✓ S5 ✓".

If any scenario fails, fix BEFORE tagging. Do not mark "known issue".
