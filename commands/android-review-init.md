---
description: Initialize .claude/CLAUDE.md scaffold (5 fields, 3 auto-detected) for the current Android project. Run once before /android-review.
---

# /android-review-init (v2.0)

Create a `.claude/CLAUDE.md` scaffold for the current Android project,
auto-filling `project-type`, `landing-mechanism`, and `backend-domain`
from the project's source. Leaves `redirect-method` and
`accepted-deviations` as TODO for the human.

Also appends `.claude/reports/` to the project's `.gitignore`.

## When to use

Run this ONCE per Android project, before the first `/android-review`.
After it creates the file, edit the `redirect-method` TODO and run the
full review.

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

## Step 4 — Auto-detect landing-mechanism

Use `Glob` and `Grep` on `app/src/main/java/**/*.kt`:
- Search for `WebView(` or `findViewById<WebView>` or
  `AndroidView { factory = { WebView`.
- Search for `CustomTabsIntent`.

Decision:
- Only WebView → `landing-mechanism = webview`.
- Only CustomTabs → `landing-mechanism = custom-tabs`.
- Both → leave as TODO with note `# TODO: choose webview or custom-tabs`.
- Neither → `landing-mechanism = none`.

## Step 5 — Auto-detect backend-domain

Use `Grep` on `app/src/main/java/**/*.kt` (and `**/*.java`) for HTTPS
URL literals matching common production-domain TLDs:
`https://[a-z0-9.-]+\.(store|app|io|dev|com)`.

Filter out:
- `localhost`, `127.0.0.1`, `10.0.2.2`.
- Common library domains: `firebase.com`, `googleapis.com`,
  `firebaseapp.com`, `crashlytics.com`, `google.com`, `android.com`,
  `developer.android.com`.

If exactly one unique domain remains → auto-fill. Else → TODO.

## Step 6 — Compute project-id

Bash: `pwd | xargs basename`, lowercase, whitespace/underscores → `-`.

## Step 7 — Create .claude/ and write CLAUDE.md

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

## landing-mechanism

<DETECTED_LANDING_MECHANISM>

## redirect-method

# TODO: Choose one of the supported methods used in this project's
# Privacy Policy → game flow:
#   - 7.1 webMessageListener
#   - 7.2 consoleLog
#   - 7.3 shouldOverrideUrlLoading
# Plugin verifies ONLY this method's correctness.
# Leave empty if landing-mechanism = none or custom-tabs.

## backend-domain

<DETECTED_BACKEND_DOMAIN_OR_TODO>

## accepted-deviations

# Lines starting with `#` are comments and are IGNORED.
# To silence a specific functional check, write a non-commented line:
#   <rule-id>: <reason why this deviation is accepted>
```

## Step 8 — Append `.claude/reports/` to project's .gitignore

```
grep -qxF '.claude/reports/' .gitignore 2>/dev/null || printf '\n# Claude Code Android Review reports\n.claude/reports/\n' >> .gitignore
```

## Step 9 — Print onboarding message

Print exactly (substitute values):

```
✅ Created .claude/CLAUDE.md for project: <project-id>

Auto-filled:
  • project-type: <project-type>
  • landing-mechanism: <landing-mechanism>
  • backend-domain: <backend-domain or "TODO">

TODO before running the full review:
  • Open .claude/CLAUDE.md and set `redirect-method` (one of 7.1 / 7.2 / 7.3).
  • If backend-domain is TODO, set it to the actual production URL.

Also done:
  • .claude/reports/ added to project's .gitignore.

Next step:
  /android-review
```

Then STOP. Do NOT run the full review automatically.

## Hard constraints

- Do NOT overwrite an existing `.claude/CLAUDE.md` (Step 2).
- Do NOT modify any project source files.
- Do NOT fabricate detected values. If detection failed, leave TODO.
