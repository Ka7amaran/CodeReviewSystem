---
description: Initialize .claude/CLAUDE.md scaffold for the current Android project. Run once before /android-review.
---

# /android-review-init

Create a `.claude/CLAUDE.md` scaffold for the current Android project,
auto-filling `project-id` and `expected-values` from
`app/build.gradle(.kts)`. Leaves placeholder TODOs for
`critical-classes` and `sensitive-files` for you to fill in.

Also appends `.claude/reports/` to the project's `.gitignore` so
generated reports don't get accidentally committed.

## When to use

Run this ONCE per Android project, **before** the first
`/android-review:android-review`. After it creates the file, edit the
two TODO sections, then run the full review.

## Usage

```
cd <android-project-root>
claude
/android-review:android-review-init
```

---

## Procedure

### Step 1 — Validate Android project root

Use `Glob` to check whether either `app/build.gradle.kts` or
`app/build.gradle` exists in the current working directory.

If neither exists, your ENTIRE response must be exactly the two lines
below — verbatim, in English, no preamble, no postamble, no translation,
no follow-up question:

```
This is not an Android project root. Expected app/build.gradle(.kts) — not found.
Did you cd to the project root before launching claude?
```

After printing those lines, STOP. Do NOT call any further tools. Do NOT
attempt to find an Android project elsewhere. Do NOT translate.

### Step 2 — Refuse to overwrite an existing CLAUDE.md

Use `Read` to load `.claude/CLAUDE.md`. If the read succeeds (the file
exists), print exactly:

```
.claude/CLAUDE.md already exists — nothing to do.

If you want to regenerate it from scratch, delete the file first:
  rm .claude/CLAUDE.md
Then run `/android-review:android-review-init` again.
```

After printing this, STOP. Do NOT call any further tools.

If the read fails with "file not found" (or equivalent), proceed to
step 3.

### Step 3 — Read gradle values

Use `Read` to load `app/build.gradle.kts` (preferred) or, if `.kts` is
absent, `app/build.gradle`. Extract these values via regex:

- `applicationId`: matches `applicationId\s*=\s*"([^"]+)"` (Kotlin DSL)
  or `applicationId\s+"([^"]+)"` (Groovy).
- `namespace`: matches `namespace\s*=\s*"([^"]+)"` or `namespace\s+"([^"]+)"`.
- `minSdk`: matches `minSdk\s*=\s*(\d+)` or `minSdk\s+(\d+)`.
- `targetSdk`: matches `targetSdk\s*=\s*(\d+)` or `targetSdk\s+(\d+)`.

If any value is not found, leave the corresponding line empty in the
template (e.g., write `applicationId: ` with nothing after the colon).
Do NOT fabricate values.

### Step 4 — Compute project-id

Run Bash:

```
pwd | xargs basename
```

Take the result. Transform it: lowercase, replace any whitespace and
underscores with `-`, collapse multiple `-` into one. This is the
`project-id`.

### Step 5 — Create `.claude/` and write CLAUDE.md

Run Bash:

```
mkdir -p .claude
```

Use the `Write` tool to create `.claude/CLAUDE.md` with this exact
content (substitute the placeholders with the values from steps 3-4):

```markdown
# Project context for Claude Code

(Free-form short description of the project. Optional.)

---

# Android Review configuration

## project-id

<PROJECT_ID_FROM_STEP_4>

## expected-values

applicationId: <FROM_GRADLE_OR_EMPTY>
namespace: <FROM_GRADLE_OR_EMPTY>
minSdk: <FROM_GRADLE_OR_EMPTY>
targetSdk: <FROM_GRADLE_OR_EMPTY>

## critical-classes

# OPTIONAL. Most modern Android projects (Hilt + kotlinx.serialization
# + Compose + Ktor) DON'T need to fill this in — those libraries ship
# their own consumer-rules in the AAR and R8 picks them up automatically.
# Your release build will Just Work with an empty proguard-rules.pro
# unless your own code does runtime reflection.
#
# Fill this section ONLY if your code uses any of:
#   - Class.forName("com.example.app.SomeClass")
#   - KClass.simpleName as a map key or registry key
#   - Custom JSON-serializer that looks up classes by string name
#   - A library that requires manual -keep rules and doesn't ship
#     consumer-rules
#
# If you do need it: list package globs whose classes must NOT be
# renamed by R8. The plugin will check that app/proguard-rules.pro
# covers them.
# Example:
# - <com.example.app.crypto.**>
# - <com.example.app.data.model.**>

## sensitive-files

# OPTIONAL. The security agent already scans every Kotlin/Java file in
# the project for hardcoded secrets, junk-char obfuscation, and plain-
# string seeds. This section just narrows the focus to specific globs
# where you KNOW secrets live — useful on large codebases to reduce
# noise.
#
# Leave empty unless your project has dedicated crypto/auth modules
# whose contents the agent should inspect more thoroughly.
# Example:
# - app/src/main/java/<your-package>/crypto/**
# - app/src/main/java/<your-package>/data/api/**

## accepted-risks

# Lines starting with `#` are comments and are IGNORED by the orchestrator.
# To actually suppress a rule, write a non-commented line:
#   <rule-id>: <reason why this risk is accepted>

## rule-overrides

# (R3 placeholder — leave empty for M1.)
```

(The `<PROJECT_ID_FROM_STEP_4>` and `<FROM_GRADLE_OR_EMPTY>` placeholders
are NOT meant to appear literally in the written file — replace them
with the actual values you extracted. The `# TODO:` and `# Example:`
comment lines DO appear literally — they're guidance for the user.)

### Step 6 — Append `.claude/reports/` to project's .gitignore

Run this exact Bash command:

```
grep -qxF '.claude/reports/' .gitignore 2>/dev/null || printf '\n# Claude Code Android Review reports\n.claude/reports/\n' >> .gitignore
```

This appends the ignore line ONLY if it's not already present. If
`.gitignore` does not exist, the `>>` redirection creates it.

### Step 7 — Print onboarding message

Print EXACTLY this (substitute `<project-id>` with the value computed
in step 4 — nothing else):

```
✅ Created .claude/CLAUDE.md for project: <project-id>

Auto-filled from gradle:
  • project-id, applicationId, namespace, minSdk, targetSdk

TODO before running the full review:
  • Open .claude/CLAUDE.md and fill the two sections marked TODO:
    - critical-classes (packages that must NOT be renamed by R8)
    - sensitive-files (where the security agent should look harder)

Also done:
  • .claude/reports/ added to project's .gitignore (so report files
    aren't committed accidentally).

Next step:
  /android-review:android-review
```

After this message, STOP. Do NOT run the full review. Do NOT call any
further tools.

---

## Hard constraints

- Do NOT overwrite an existing `.claude/CLAUDE.md`. If it exists, abort
  per Step 2.
- Do NOT modify any project source files.
- Do NOT fabricate gradle values. If a regex doesn't match, leave the
  field empty.
- Do NOT auto-fill `critical-classes` or `sensitive-files` — those
  decisions require human judgment.
