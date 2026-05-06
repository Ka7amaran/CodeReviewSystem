---
description: Initialize .claude/CLAUDE.md scaffold (2 fields, 1 auto-detected) for the current Android project. Run once before /android-review.
---

# /android-review-init (v2.2)

Create a `.claude/CLAUDE.md` scaffold for the current Android project,
auto-filling `project-type` from the project's source. Leaves
`accepted-deviations` empty (filled only when needed to silence a
specific finding).

The other three values that v2.0/v2.1 required (`landing-mechanism`,
`redirect-method`, `backend-domain`) are now **detected from code at
review time** by the validator's Stage 0 — no manual declaration
needed.

Also appends `.claude/reports/` to the project's `.gitignore`.

## When to use

Run this ONCE per Android project, before the first `/android-review`.
After it creates the file, you can run `/android-review` immediately —
no further editing is needed in the typical case.

## Usage

```
cd <android-project-root>
claude
/android-review-init
```

---

## Step 1 — Validate Android project root

Same hard-abort as `/android-review`. If neither
`app/build.gradle.kts` nor `app/build.gradle` exists, print exactly:

```
This is not an Android project root. Expected app/build.gradle(.kts) — not found.
Did you cd to the project root before launching claude?
```

Then STOP.

## Step 2 — Refuse to overwrite existing CLAUDE.md

Use `Read` on `.claude/CLAUDE.md`. If the file exists, print exactly:

```
.claude/CLAUDE.md already exists — nothing to do.

If you want to regenerate it from scratch, delete the file first:
  rm .claude/CLAUDE.md
Then run `/android-review-init` again.
```

Then STOP.

If the read fails with file-not-found, proceed.

## Step 3 — Auto-detect project-type

Use `Read` on `gradle/libs.versions.toml` (preferred) or
`app/build.gradle.kts`. Look for any of:
- `OneSignal` (case-insensitive substring)
- `installreferrer`
- `play-services-ads-identifier`

If at least one is present → `project-type = with-attribution`.
Otherwise → `project-type = no-attribution`.

## Step 4 — Compute project-id

Bash: `pwd | xargs basename`, lowercase, whitespace/underscores → `-`.

## Step 5 — Create .claude/ and write CLAUDE.md

Bash: `mkdir -p .claude`.

Use `Write` to create `.claude/CLAUDE.md` with this content (substitute
detected values):

```markdown
# Project context for Claude Code

(Free-form short description, optional.)

---

# Android Review configuration

## project-id

<COMPUTED_PROJECT_ID>

## project-type

<DETECTED_PROJECT_TYPE>

## accepted-deviations

# Lines starting with `#` are comments and are IGNORED.
# To silence a specific functional check, write a non-commented line:
#   <rule-id>: <reason why this deviation is accepted>
#
# Note: as of v2.2.0, landing-mechanism / redirect-method /
# backend-domain are no longer declared here — the validator detects
# them from your code automatically.
```

## Step 6 — Append `.claude/reports/` to project's .gitignore

```
grep -qxF '.claude/reports/' .gitignore 2>/dev/null || printf '\n# Claude Code Android Review reports\n.claude/reports/\n' >> .gitignore
```

## Step 7 — Print onboarding message

Print exactly (substitute values):

```
✅ Created .claude/CLAUDE.md for project: <project-id>

Auto-filled:
  • project-type: <project-type>

(landing-mechanism, redirect-method, backend-domain are detected
 from your code at review time — no manual declaration needed.)

Also done:
  • .claude/reports/ added to project's .gitignore.

Next step:
  /android-review
```

Then STOP. Do NOT run the full review automatically.

## Hard constraints

- Do NOT overwrite an existing `.claude/CLAUDE.md` (Step 2).
- Do NOT modify any project source files.
- Do NOT fabricate the detected project-type. If detection is
  ambiguous, default to `with-attribution` (more inclusive).
