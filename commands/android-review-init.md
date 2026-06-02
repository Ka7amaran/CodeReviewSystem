---
description: Initialize .claude/CLAUDE.md scaffold (2 fields, 1 auto-detected) for the current Android project. Run once before /android-review.
---

# /android-review-init (v2.3)

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

## Step 3 — Pre-flight: detect app completeness

**Goal.** Catch the case where init runs against the wrong branch or a
stub checkout (empty `main`, scaffold-only branch). We probe three
markers that a real team app always carries — if 2+ are missing, the
project is almost certainly not the "full" version and the operator
should switch branches before generating `CLAUDE.md`.

**The three markers:**

- **WebView / Chrome CustomTabs** — `android.webkit.WebView` or
  `androidx.browser.customtabs.CustomTabsIntent` (core of every team
  app).
- **Install Referrer Client** — Google Play Install Referrer
  (`com.android.installreferrer:installreferrer` /
  `InstallReferrerClient`).
- **OneSignal SDK** — `com.onesignal:OneSignal` push/messaging.

A marker counts as **found** if it appears in ANY of these places
(positive hit in one is enough — do not require all three locations):

1. `app/build.gradle.kts`, `app/build.gradle`, or
   `gradle/libs.versions.toml` (SDK coordinates).
2. `app/src/main/AndroidManifest.xml` (declared services / activities).
3. Files under `app/src/main/java/` or `app/src/main/kotlin/` (imports
   or type references).

**Probe commands.** Run via Bash (prefer `rg`; fall back to `grep -rE`
if ripgrep is unavailable):

```
WEBVIEW_HIT=$(rg -l -e 'android\.webkit\.WebView' -e 'androidx\.browser\.customtabs' app/ gradle/ 2>/dev/null | head -n1)
REFERRER_HIT=$(rg -l -e 'com\.android\.installreferrer' -e 'InstallReferrerClient' app/ gradle/ 2>/dev/null | head -n1)
ONESIGNAL_HIT=$(rg -l -e 'com\.onesignal' -e 'OneSignal' app/ gradle/ 2>/dev/null | head -n1)

FOUND=0
[ -n "$WEBVIEW_HIT" ]   && FOUND=$((FOUND+1))
[ -n "$REFERRER_HIT" ]  && FOUND=$((FOUND+1))
[ -n "$ONESIGNAL_HIT" ] && FOUND=$((FOUND+1))
```

Also collect for the warning message (best-effort — do not fail if any
return empty):

```
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '<no-git>')
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo '<no-git>')
OTHER_BRANCHES=$(git for-each-ref --sort=-committerdate refs/heads/ \
    --format='  %(refname:short)  %(committerdate:short)  %(subject)' \
    2>/dev/null | grep -v "^  $BRANCH " | head -n5)
```

**Threshold.**

- If `FOUND >= 2` → print `Pre-flight: $FOUND/3 completeness markers detected (PASS).`
  and continue to Step 4.
- If `FOUND <= 1` → print the warning block below (substitute values;
  show the literal `(none)` when a list is empty):

```
⚠️  Pre-flight: only <FOUND>/3 completeness markers detected.
   This looks like a stub or wrong-branch checkout.

  Branch:  <BRANCH>
  SHA:     <SHA>
  Found:   <comma-list of marker names that hit, or "(none)">
  Missing: <comma-list of marker names that did NOT hit>

  Other local branches (most recently committed first):
<OTHER_BRANCHES — or the literal line "  (none found)" if empty>
```

Then call **AskUserQuestion** with:

- `header`: `"Proceed?"`
- `question`: `"Це справді повна версія, для якої треба згенерувати CLAUDE.md?"`
- `options`:
  - `{ label: "Так — продовжуй", description: "Знаю що роблю; продовжити init на поточній гілці." }`
  - `{ label: "Ні — зупини", description: "Зупини init; перемкнусь на іншу гілку і запущу заново." }`

If the user answers **"Так — продовжуй"** → continue to Step 4.
If the user answers **"Ні — зупини"** or selects **"Other"** → STOP.
Do NOT create `.claude/CLAUDE.md`. Do NOT modify `.gitignore`. Print:

```
Init aborted. Switch to the right branch (or pull the full version)
and re-run `/android-review-init`.
```

## Step 4 — Auto-detect project-type

Use `Read` on `gradle/libs.versions.toml` (preferred) or
`app/build.gradle.kts`. Look for any of:
- `OneSignal` (case-insensitive substring)
- `installreferrer`
- `play-services-ads-identifier`

If at least one is present → `project-type = with-attribution`.
Otherwise → `project-type = no-attribution`.

## Step 5 — Compute project-id

Bash: `pwd | xargs basename`, lowercase, whitespace/underscores → `-`.

## Step 6 — Create .claude/ and write CLAUDE.md

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

## Step 7 — Append `.claude/reports/` to project's .gitignore

```
grep -qxF '.claude/reports/' .gitignore 2>/dev/null || printf '\n# Claude Code Android Review reports\n.claude/reports/\n' >> .gitignore
```

## Step 8 — Print onboarding message

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

- Do NOT skip Step 3's pre-flight check. If the user answers
  «Ні — зупини» (or chooses «Other»), STOP without creating any files.
- Do NOT overwrite an existing `.claude/CLAUDE.md` (Step 2).
- Do NOT modify any project source files.
- Do NOT fabricate the detected project-type. If detection is
  ambiguous, default to `with-attribution` (more inclusive).
