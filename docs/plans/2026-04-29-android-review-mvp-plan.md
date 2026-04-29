# Android Review System — MVP (M1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the MVP of an Android Review plugin for Claude Code: orchestrator + 3 sub-agents + 9 rules + project CLAUDE.md template, deployable as a Claude Code marketplace plugin and verifiable via manual smoke-test on two real Android projects (`Juice-Master-Factory`, `Joker-Speed-Seven`).

**Architecture:** The marketplace plugin lives at the root of `/Users/mac/CodeReviewSystem/`. Orchestrator (`/android-review`) dispatches three parallel sub-agents (style/security/obfuscation); each reads its rules from `rules/<category>/`. Per-project `.claude/CLAUDE.md` provides context (`project-id`, `expected-values`, `critical-classes`, `sensitive-files`, `accepted-risks`). Plugin operates under a read-only sandbox (deny `Edit`/`Write`). Reports are saved as markdown + Google-Docs-friendly text in `.claude/reports/` inside the project being reviewed (stable name + `archive/`).

**Tech Stack:** Markdown (rule files, agent prompts), YAML frontmatter (rule metadata), Claude Code plugin format (`.claude-plugin/plugin.json`), Bash for manual verification. Targets Android Kotlin / Jetpack Compose / Hilt projects.

**Source spec:** `docs/specs/2026-04-29-android-review-system-design.md`.

**Out of scope (deferred to M2/M3):** rule library beyond the 9 MVP rules, R3 (rule-overrides) parsing, CI integration, Asana validation, auto-fix.

---

## File Structure (M1)

```
/Users/mac/CodeReviewSystem/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── CHANGELOG.md
├── .gitignore
├── commands/
│   ├── android-review.md
│   ├── android-review-style.md
│   ├── android-review-security.md
│   └── android-review-obfuscation.md
├── agents/
│   ├── orchestrator.md
│   ├── style-auditor.md
│   ├── security-auditor.md
│   └── obfuscation-auditor.md
├── rules/
│   ├── _schema.md
│   ├── _template.md
│   ├── style/
│   │   ├── kotlin-naming-conventions.md
│   │   ├── compose-stable-parameters.md
│   │   └── hilt-no-field-injection.md
│   ├── security/
│   │   ├── no-cleartext-traffic.md
│   │   ├── no-hardcoded-secrets.md
│   │   └── exported-component-without-permission.md
│   └── obfuscation/
│       ├── proguard-rules-not-empty.md
│       ├── crypto-classes-keep-rules-present.md
│       └── seed-keys-not-plain-string.md
├── docs/
│   ├── specs/                                     # already exists
│   ├── plans/                                     # this file lives here
│   ├── how-to-add-a-rule.md
│   ├── project-claude-md-template.md
│   └── smoke-test.md
└── examples/
    ├── good-claude-md-for-project.md
    ├── good-proguard-rules.pro
    └── claude-md-gitignore.txt
```

**Boundaries (each file has one responsibility):**
- `commands/*.md` — thin wrappers, contain only command definition + reference to agent + permission denylist.
- `agents/*.md` — system prompts; describe **procedure**, not specific rules.
- `rules/*/*.md` — single rule each, frontmatter + 5 body sections per spec §5.1.
- `docs/*.md` — human documentation; not consumed by the plugin runtime.
- `examples/*` — referenced from rules and docs as canonical good shapes.

---

## Verification model (no automated tests)

After every task that creates a *callable* artefact (commands wired to an agent), there is a manual verification step. Earlier structural tasks (scaffold, individual rules, individual agents in isolation) verify only file syntax (`jq` for JSON, `yq` or `head` for YAML frontmatter, presence of mandatory sections). The **first end-to-end run** is at Task 11; the **full 5-scenario smoke-test** is Task 12.

**Engineer must `cd /Users/mac/CodeReviewSystem` before running any commands in this plan unless an absolute path is given.**

---

## Task 1: Plugin scaffold

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `README.md`
- Create: `CHANGELOG.md`
- Create: `.gitignore`

- [ ] **Step 1: Create `.claude-plugin/plugin.json`**

```bash
mkdir -p .claude-plugin
```

Write `/Users/mac/CodeReviewSystem/.claude-plugin/plugin.json`:

```json
{
  "name": "android-review",
  "version": "1.0.0",
  "description": "Automated code review for Android (Kotlin/Compose/Hilt) projects: style, security, obfuscation. Orchestrator + 3 parallel sub-agents reading declarative markdown rules.",
  "author": {
    "name": "Roman"
  },
  "homepage": "https://github.com/<owner>/CodeReviewSystem",
  "keywords": ["android", "kotlin", "code-review", "security", "proguard", "obfuscation"]
}
```

- [ ] **Step 2: Create `README.md`**

Write `/Users/mac/CodeReviewSystem/README.md` with these sections:

1. **What this is** (2–3 sentences from spec §1).
2. **Install** — single fenced block:
   ```
   /plugin marketplace add github:<owner>/CodeReviewSystem
   /plugin install android-review@<owner>-marketplace
   ```
3. **Use** — single fenced block:
   ```
   cd ~/StudioProjects/<your-android-project>
   claude
   /android-review
   ```
4. **Per-project setup** — link to `docs/project-claude-md-template.md`. Single sentence: "Each Android project needs a `.claude/CLAUDE.md` declaring its `project-id`, `critical-classes`, and `sensitive-files`. See template."
5. **Commands** — bullet list of the four slash-commands and what each does (one line each).
6. **Adding rules** — link to `docs/how-to-add-a-rule.md`.
7. **Architecture** — link to `docs/specs/2026-04-29-android-review-system-design.md`.

Keep README under 100 lines. No badges, no marketing.

- [ ] **Step 3: Create `CHANGELOG.md`**

Write `/Users/mac/CodeReviewSystem/CHANGELOG.md`:

```markdown
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
```

- [ ] **Step 4: Create `.gitignore`**

Write `/Users/mac/CodeReviewSystem/.gitignore`:

```
# OS
.DS_Store
Thumbs.db

# Editors
.idea/
.vscode/
*.swp

# Local Claude Code state (do NOT ignore .claude-plugin/)
.claude/reports/
.claude/local-settings.json
```

- [ ] **Step 5: Verify structure**

Run:

```bash
cd /Users/mac/CodeReviewSystem
jq -e '.name == "android-review" and .version == "1.0.0"' .claude-plugin/plugin.json
test -f README.md && test -f CHANGELOG.md && test -f .gitignore && echo OK
```

Expected: `true` from `jq`, then `OK`. If `jq` exits non-zero, fix the JSON.

- [ ] **Step 6: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add .claude-plugin/plugin.json README.md CHANGELOG.md .gitignore
git commit -m "feat: add plugin scaffold (manifest, README, changelog, gitignore)"
```

---

## Task 2: Rule schema and template

**Files:**
- Create: `rules/_schema.md`
- Create: `rules/_template.md`

- [ ] **Step 1: Create `rules/_schema.md`**

This is human documentation describing what a rule file looks like. Write `/Users/mac/CodeReviewSystem/rules/_schema.md`:

```markdown
# Rule file schema

Every rule lives in `rules/<category>/<rule-id-slug>.md` where `category`
is one of `style`, `security`, `obfuscation`. The filename slug must
match the `id` field after the `/`.

## Frontmatter (5 mandatory fields)

```yaml
---
id: <category>/<slug>            # e.g. security/no-cleartext-traffic
severity: error | warning | info  # error = blocks release; warning = must review; info = observation
category: style | security | obfuscation   # duplicates first id segment
applies-to:                       # glob patterns; agent skips body if no match
  - <pattern>
  - <pattern>
since: "<semver>"                 # plugin version that introduced the rule
---
```

## Body (5 mandatory sections, each `## Heading`)

1. **`## Чому це важливо`** — 2–6 sentences explaining business/security
   context. Without this section the developer does not understand why
   they're being told this. Reduces review fatigue.
2. **`## Що перевірити`** — numbered checklist for the agent. This is
   the "program" of the rule.
3. **`## Як це виглядає у поганому проекті`** — minimal failing example.
4. **`## Як це має виглядати`** — minimal correct example.
5. **`## Як доповідати`** — exact report-line template. Critical for
   consistent reports across runs.
6. **`## Виключення`** — when (if ever) the rule may be suppressed via
   `accepted-risks` in a project's `CLAUDE.md`. Use the literal text
   `Жодних` (or `None`) if the rule cannot be suppressed.

## How sub-agents apply rules (reference)

1. Read the frontmatter of every file in `rules/<own-category>/`.
2. Filter by `applies-to`: skip rules whose patterns don't match any
   project file.
3. For survivors, read the body.
4. Read `accepted-risks` from `.claude/CLAUDE.md` of the project; for
   each suppressed rule, check whether its `## Виключення` allows it.
5. Apply `## Що перевірити` to the project, formulate findings using
   `## Як доповідати`.
6. Group findings by severity in the final markdown report.
```

- [ ] **Step 2: Create `rules/_template.md`**

Write `/Users/mac/CodeReviewSystem/rules/_template.md` — a copy-paste starting point for new rules:

```markdown
---
id: <category>/<slug>
severity: error
category: <category>
applies-to:
  - <glob>
since: "1.0.0"
---

# <Human-readable rule title>

## Чому це важливо

(2–6 sentences explaining the why, not the what.)

## Що перевірити

1. (First check the agent should perform — concrete, file/attribute level.)
2. (Second check.)
3. (...)

## Як це виглядає у поганому проекті

```
(minimal example showing the violation)
```

## Як це має виглядати

```
(minimal example of the correct shape)
```

## Як доповідати

```
[<rule-id>] <SEVERITY>
  <file>:<line>
  <one-sentence finding>
  Fix: <one-sentence fixer>.
  See: <examples/... or external link>.
```

## Виключення

(When suppression via accepted-risks is allowed — or "Жодних".)
```

- [ ] **Step 3: Verify both files have valid frontmatter shape**

```bash
cd /Users/mac/CodeReviewSystem
head -10 rules/_schema.md | grep -q "^# Rule file schema$" && \
  head -10 rules/_template.md | grep -q "^---$" && echo OK
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add rules/_schema.md rules/_template.md
git commit -m "feat(rules): add rule schema documentation and template"
```

---

## Task 3: Project CLAUDE.md template and `.gitignore` snippet

**Files:**
- Create: `docs/project-claude-md-template.md`
- Create: `examples/good-claude-md-for-project.md`
- Create: `examples/claude-md-gitignore.txt`

- [ ] **Step 1: Create `docs/project-claude-md-template.md`**

Authoritative documented template, exactly the shape of spec §6.1. Write `/Users/mac/CodeReviewSystem/docs/project-claude-md-template.md`:

```markdown
# Project `.claude/CLAUDE.md` template

Place this file at the root of an Android project that will be reviewed
with `/android-review`. It serves two purposes simultaneously:

1. Project context auto-loaded by Claude Code.
2. Machine-readable declarations parsed by the orchestrator.

## Template (copy-paste, then fill 4 sections)

```markdown
# Project context for Claude Code

(Free-form short description of the project. Optional.)

---

# Android Review configuration

## project-id

<short-kebab-case-id>

## expected-values

applicationId: <com.example.app>
namespace: <com.example.app>
minSdk: 26
targetSdk: 36

## critical-classes

- <com.example.app.crypto.**>
- <com.example.app.data.model.**>

## sensitive-files

- app/src/main/java/<path-glob>/**

## accepted-risks

# rule-id: justification

## rule-overrides

# (R3 placeholder — leave empty for M1.)
```

## Section reference

| Section            | Purpose                                                            | Required? |
|--------------------|--------------------------------------------------------------------|-----------|
| `project-id`       | Human-readable id used in report titles and filenames.             | Yes       |
| `expected-values`  | Optional baseline validation of `applicationId`/`namespace`/SDK.   | No        |
| `critical-classes` | Glob patterns that must be covered by `-keep` rules.               | Yes (recommended) |
| `sensitive-files`  | Glob patterns where the security agent searches harder.            | Yes (recommended) |
| `accepted-risks`   | `<rule-id>: <reason>` — silences a rule if its "Виключення" allows.| Optional  |
| `rule-overrides`   | Reserved for future R3 per-project rule parameter overrides.       | Leave empty |

## What happens if `.claude/CLAUDE.md` is missing

The plugin does not fail. Agents fall back to defaults:
- `expected-values` checks are skipped.
- `critical-classes` are heuristically detected by name patterns
  (`*crypto*`, `*decrypt*`, `*Cipher*`, `*Auth*`, `Key*`).
- `sensitive-files` defaults to all Kotlin files; expect more noise.
- `accepted-risks` is empty.

The report header reflects the missing file with `CLAUDE.md: missing ⚠️`.

## What to gitignore

Reports are generated under `.claude/reports/` inside the project.
Add this to your project's `.gitignore`:

```
.claude/reports/
```

`.claude/CLAUDE.md` itself is **not** gitignored — it is configuration,
and changes to it must be PR-reviewed by your team.
```

- [ ] **Step 2: Create `examples/good-claude-md-for-project.md`**

A complete, fictional but realistic example. Write `/Users/mac/CodeReviewSystem/examples/good-claude-md-for-project.md`:

```markdown
# Project context for Claude Code

Sample Android casual game built with Kotlin + Jetpack Compose + Hilt.
Splash queries a remote config endpoint, then either gameplay or a
WebView landing flow. AAID + OneSignal + Install Referrer integrations.

---

# Android Review configuration

## project-id

example-juicer

## expected-values

applicationId: com.example.juicer
namespace: com.example.juicer
minSdk: 26
targetSdk: 36

## critical-classes

- com.example.juicer.core.crypto.**
- com.example.juicer.data.model.**
- com.example.juicer.data.api.dto.**

## sensitive-files

- app/src/main/java/com/example/juicer/core/crypto/**
- app/src/main/java/com/example/juicer/data/api/**

## accepted-risks

# Example: this project intentionally suppresses one rule with a written reason.
# security/exported-component-without-permission: MainActivity is the launcher; intent-filter is the permission boundary.

## rule-overrides

# (R3 placeholder — leave empty for M1.)
```

- [ ] **Step 3: Create `examples/claude-md-gitignore.txt`**

A snippet that the engineer pastes into the Android project's `.gitignore`. Write `/Users/mac/CodeReviewSystem/examples/claude-md-gitignore.txt`:

```
# Claude Code Android Review reports (auto-generated)
.claude/reports/
```

- [ ] **Step 4: Verify**

```bash
cd /Users/mac/CodeReviewSystem
test -f docs/project-claude-md-template.md && \
  test -f examples/good-claude-md-for-project.md && \
  test -f examples/claude-md-gitignore.txt && echo OK
grep -q "## project-id" examples/good-claude-md-for-project.md && \
  grep -q "## critical-classes" examples/good-claude-md-for-project.md && \
  echo "sections OK"
```

Expected: `OK` and `sections OK`.

- [ ] **Step 5: Commit**

```bash
git add docs/project-claude-md-template.md examples/good-claude-md-for-project.md examples/claude-md-gitignore.txt
git commit -m "feat(docs): add project CLAUDE.md template and example"
```

---

## Task 4: Security auditor agent + 3 rules

**Files:**
- Create: `agents/security-auditor.md`
- Create: `rules/security/no-cleartext-traffic.md`
- Create: `rules/security/no-hardcoded-secrets.md`
- Create: `rules/security/exported-component-without-permission.md`

- [ ] **Step 1: Create `agents/security-auditor.md`**

Write `/Users/mac/CodeReviewSystem/agents/security-auditor.md`:

````markdown
---
name: security-auditor
description: Security audit sub-agent for Android projects. Reads rules from rules/security/, applies them, returns a structured markdown report. Read-only.
tools: [Read, Glob, Grep]
---

You are **security-auditor**, a sub-agent of the android-review plugin.

## Your job

Apply every rule in `rules/security/` to the Android project located at
the current working directory and produce one markdown report.

## Procedure (follow exactly)

1. Discover rules:
   - List every `*.md` file in `rules/security/` of the plugin
     directory (your own filesystem, not the project's).
   - For each rule file, parse the YAML frontmatter only at first.
   - Skip files starting with `_` (those are schema/template).

2. Filter by `applies-to`:
   - For each rule, check whether at least one of its `applies-to`
     glob patterns matches a file in the project under review.
   - If none matches, **skip** the rule. Record the skip and reason in
     a `skipped` list.

3. Read project context:
   - Try to read `.claude/CLAUDE.md` from the project root.
   - Parse the `## accepted-risks` section. Each line is
     `<rule-id>: <reason>` (lines starting with `#` are comments).
   - If `.claude/CLAUDE.md` is missing, proceed with empty
     `accepted-risks`.

4. For each surviving rule:
   a. Read the full rule body.
   b. If the rule's `id` is in `accepted-risks`:
      - Read the rule's `## Виключення` section.
      - If it says "Жодних" or "None", **do not** suppress. Add a
        `warning` finding noting that an attempt to accept this risk
        was rejected.
      - Otherwise, skip the rule and record it under `accepted` with
        the user-provided reason.
   c. Apply the rule's `## Що перевірити` checklist to the project.
   d. For every violation found, formulate a finding using the rule's
      `## Як доповідати` template literally.

5. Group findings by `severity` (`error`, `warning`, `info`).

6. Output exactly this markdown:

```
## Security audit

**Rules applied:** <N>
**Rules skipped (applies-to):** <S1>
**Rules accepted as risk:** <S2>

### Errors

(... finding blocks ...)

### Warnings

(... finding blocks ...)

### Info

(... finding blocks ...)

### Skipped rules

- <rule-id> — <reason>
```

If a category has zero findings, write `(none)` under it.

## Hard constraints

- You **must not** modify any file. You have only Read/Glob/Grep.
- If a rule has invalid frontmatter, skip it and add to `Skipped` with
  reason `invalid frontmatter`. Do not fail.
- Do not invent rules. Apply only what is in `rules/security/`.
- Do not echo the rule body in your report; only the finding template.
- Use the project's relative paths (e.g., `app/src/main/...`) in
  findings, not absolute paths.
````

- [ ] **Step 2: Create `rules/security/no-cleartext-traffic.md`**

```bash
mkdir -p rules/security
```

Write `/Users/mac/CodeReviewSystem/rules/security/no-cleartext-traffic.md`:

```markdown
---
id: security/no-cleartext-traffic
severity: error
category: security
applies-to:
  - app/src/main/AndroidManifest.xml
  - app/src/main/res/xml/network_security_config.xml
since: "1.0.0"
---

# No cleartext traffic in release builds

## Чому це важливо

Cleartext HTTP traffic enables MITM attacks, parameter capture, and
response tampering. Google Play marks `usesCleartextTraffic="true"` as
high-severity in pre-launch reports and may reject apps that handle
sensitive flows (auth, payments, attribution) over plain HTTP. Even
when the dev believes the endpoint is internal, attackers on the same
network can intercept it.

## Що перевірити

1. In `app/src/main/AndroidManifest.xml`, the `<application>` element
   must NOT have `android:usesCleartextTraffic="true"`.
2. If `app/src/main/res/xml/network_security_config.xml` exists, it
   must NOT contain a `<base-config cleartextTrafficPermitted="true">`
   without a domain-scoped `<domain-config>` overriding it.
3. If cleartext is intentionally required (e.g., a local dev endpoint),
   it must be scoped via `<domain-config>` AND declared in
   `.claude/CLAUDE.md` `accepted-risks` with a written reason.

## Як це виглядає у поганому проекті

```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

## Як це має виглядати

```xml
<application
    ...>  <!-- attribute absent or "false" -->
```

If cleartext truly is needed for one domain, use:

```xml
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">10.0.2.2</domain>
    </domain-config>
</network-security-config>
```

## Як доповідати

```
[security/no-cleartext-traffic] ERROR
  app/src/main/AndroidManifest.xml:<line>
  android:usesCleartextTraffic="true" set on <application>.
  Fix: remove the attribute, or scope cleartext to one domain via network_security_config.xml.
  See: examples/ (none yet — see https://developer.android.com/training/articles/security-config)
```

## Виключення

Жодних. Per-domain scoping via `network_security_config.xml` is the
only acceptable workaround.
```

- [ ] **Step 3: Create `rules/security/no-hardcoded-secrets.md`**

Write `/Users/mac/CodeReviewSystem/rules/security/no-hardcoded-secrets.md`:

```markdown
---
id: security/no-hardcoded-secrets
severity: error
category: security
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "1.0.0"
---

# No plain-string secrets, seeds, or API keys

## Чому це важливо

Strings constants in Kotlin/Java compile into the APK as readable UTF-8.
Decompilers (`apktool`, `jadx`) extract them in seconds. A "hidden" AES
seed, OneSignal app id, signing salt, or backend URL stored as a plain
`const val` provides zero protection. Junk-character obfuscation
(building a string from a `charArrayOf(...)` with index picking) is
trivially reversible by any reverse-engineer with five minutes.

## Що перевірити

1. Search files matching `sensitive-files` (from project's
   `.claude/CLAUDE.md`; if missing, search all `.kt`/`.java`).
2. For each file, flag occurrences of:
   a. Plain `const val` / `val` / `String` literals 24+ chars long
      that look like Base64 (`[A-Za-z0-9+/_-]{24,}=*`) or hex
      (`[A-Fa-f0-9]{32,}`).
   b. Variables named `*_SEED`, `*Seed`, `*KEY`, `*Key`, `*SECRET`,
      `*Token`, `*PASSWORD` whose value is a plain string literal.
   c. Plain literals matching attribution endpoint patterns
      (`http://`, `https://api.`, `https://` + IP).
3. Distinguish from already-encrypted blobs (those usually pair with a
   visible AES/Base64 decryption helper). If the file imports
   `javax.crypto.Cipher` and decrypts the blob via a helper, downgrade
   to `warning` instead of `error`, but still report — the seed itself
   is the weak link.

## Як це виглядає у поганому проекті

```kotlin
// rules/security/no-hardcoded-secrets — example bad
val USER_SEED: ByteArray = "K9mT4Xq2Zp7Lw1R8Ys5Nv6Hd3Fa0BcJu".toByteArray()

object KeyGeneral {
    const val key1 = "abcd1234efgh5678..."
}
```

## Як це має виглядати

The seed must come from outside the APK: NDK-stored, server-derived,
KeyStore-bound, or split across multiple compiled artefacts whose
recombination is non-obvious. For early MVP, store in `BuildConfig`
fields populated from local `gradle.properties` (still trivial, but
removes from source) and treat the rule as "warning at minimum".

## Як доповідати

```
[security/no-hardcoded-secrets] ERROR
  <file>:<line>
  Plain-string secret/seed: <variable-name> = "<first-8-chars>...<last-4>" (<length> chars).
  Fix: do not embed seeds as compile-time string constants. Move to BuildConfig from gradle.properties at minimum, or to NDK/KeyStore for production.
  See: https://developer.android.com/privacy-and-security/keystore
```

## Виключення

Дозволено через `accepted-risks`, **тільки** якщо:
- це not a credential/secret (наприклад, public namespace prefix), і
- код містить коментар, що пояснює чому.

Інакше — заборонено.
```

- [ ] **Step 4: Create `rules/security/exported-component-without-permission.md`**

Write `/Users/mac/CodeReviewSystem/rules/security/exported-component-without-permission.md`:

```markdown
---
id: security/exported-component-without-permission
severity: warning
category: security
applies-to:
  - app/src/main/AndroidManifest.xml
since: "1.0.0"
---

# Exported components must declare an explicit permission boundary

## Чому це важливо

`android:exported="true"` on an Activity/Service/Receiver/Provider
makes it callable by any other app on the device. If the only "guard"
is a missing intent-filter or implicit assumption, a malicious app can
launch the component with crafted extras, exfiltrating data or
triggering privileged behavior. The launcher Activity is a known
exception (its intent-filter is the permission boundary), but every
other exported component must either (a) declare
`android:permission` referencing a signature-protected permission, or
(b) be explicitly opted in via `accepted-risks`.

## Що перевірити

1. In `app/src/main/AndroidManifest.xml`, list every
   `<activity>`/`<service>`/`<receiver>`/`<provider>` with
   `android:exported="true"`.
2. For each, check:
   a. If it is the launcher Activity (has `<action android:name="android.intent.action.MAIN" />`
      with `<category android:name="android.intent.category.LAUNCHER" />`), it is permitted.
   b. If it has `android:permission="..."`, it is permitted (but
      verify the permission's `protectionLevel` is `signature` if it
      is a custom one).
   c. Otherwise — flag.
3. Cross-reference with `accepted-risks`. If suppressed, downgrade to
   `info`.

## Як це виглядає у поганому проекті

```xml
<service
    android:name=".PushService"
    android:exported="true" />   <!-- no permission, not the launcher -->
```

## Як це має виглядати

```xml
<service
    android:name=".PushService"
    android:exported="true"
    android:permission="com.example.app.permission.RECEIVE_PUSH" />
```

…with a matching `<permission android:protectionLevel="signature" .../>`.

## Як доповідати

```
[security/exported-component-without-permission] WARNING
  app/src/main/AndroidManifest.xml:<line>
  <component-tag> "<name>" is exported but has no android:permission and is not the launcher Activity.
  Fix: add android:permission with a signature-level custom permission, or set android:exported="false" if not consumed externally.
  See: https://developer.android.com/guide/topics/manifest/activity-element#exported
```

## Виключення

Дозволено через `accepted-risks` тільки з обґрунтуванням, що компонент
свідомо публічний (наприклад, deeplink-handler з санітизацією на вході).
Reason rule must say so explicitly.
```

- [ ] **Step 5: Verify all four files exist and have valid frontmatter**

```bash
cd /Users/mac/CodeReviewSystem
for f in agents/security-auditor.md rules/security/*.md; do
  test -f "$f" || { echo "MISSING: $f"; exit 1; }
  head -1 "$f" | grep -q "^---$" || { echo "BAD FRONTMATTER: $f"; exit 1; }
done
echo OK
```

Expected: `OK`.

- [ ] **Step 6: Commit**

```bash
git add agents/security-auditor.md rules/security/
git commit -m "feat(security): add security-auditor agent and 3 starter rules"
```

---

## Task 5: Obfuscation auditor agent + 3 rules

**Files:**
- Create: `agents/obfuscation-auditor.md`
- Create: `rules/obfuscation/proguard-rules-not-empty.md`
- Create: `rules/obfuscation/crypto-classes-keep-rules-present.md`
- Create: `rules/obfuscation/seed-keys-not-plain-string.md`

- [ ] **Step 1: Create `agents/obfuscation-auditor.md`**

Write `/Users/mac/CodeReviewSystem/agents/obfuscation-auditor.md` using the **same structure** as `security-auditor.md` (Task 4 Step 1). Replace category-specific text:

- Frontmatter `name: obfuscation-auditor`, description mentions ProGuard/R8, classes preservation, junk obfuscation effectiveness.
- Procedure step 1: read `rules/obfuscation/*.md`.
- Procedure step 3: also read `critical-classes` from `.claude/CLAUDE.md` — this list drives one of the rules (`crypto-classes-keep-rules-present`).
- Output section heading: `## Obfuscation audit`.
- Hard constraints identical (read-only, no fabrication).

Specifically include this paragraph in the agent's "Procedure" before applying rules:

```
Before applying rules, build a "critical classes set":
- If .claude/CLAUDE.md provides a non-empty `critical-classes` section,
  use it.
- Else, scan `app/src/main/java/**` for class names matching
  /(?i)(crypto|decrypt|cipher|encrypt|seed|secret|token|auth|key)/
  and present the top 20 to the report under "auto-detected critical
  classes — consider declaring in CLAUDE.md".
```

- [ ] **Step 2: Create `rules/obfuscation/proguard-rules-not-empty.md`**

Write `/Users/mac/CodeReviewSystem/rules/obfuscation/proguard-rules-not-empty.md`:

```markdown
---
id: obfuscation/proguard-rules-not-empty
severity: error
category: obfuscation
applies-to:
  - app/proguard-rules.pro
  - app/build.gradle.kts
  - app/build.gradle
since: "1.0.0"
---

# Non-empty ProGuard rules when minify is enabled

## Чому це важливо

If `isMinifyEnabled = true` in `release` build type but
`proguard-rules.pro` is empty (only the default template comments),
R8 will rename and possibly strip classes that the app accesses
reflectively (Hilt entry points, Compose runtime markers, kotlinx.
serialization annotations, JSON DTOs deserialized via reflection).
Result: silent runtime crashes in release that cannot be reproduced
in debug. This is one of the most common pre-launch outages.

## Що перевірити

1. In `app/build.gradle.kts` (or `.gradle`), find `buildTypes { release { ... } }`.
2. Detect `isMinifyEnabled = true` (Kotlin DSL) or
   `minifyEnabled true` (Groovy).
3. If minify is enabled, read `app/proguard-rules.pro`.
4. The file is considered "empty" if, after stripping `#`-comments and
   blank lines, fewer than 3 non-comment lines remain.
5. If empty + minify enabled → ERROR.

## Як це виглядає у поганому проекті

```
# Add project specific ProGuard rules here.
# (template-only comments)
```

…paired with `isMinifyEnabled = true` in gradle.

## Як це має виглядати

A non-trivial set of `-keep` rules tailored to the project's
reflective surfaces (DI, JSON, Compose markers, critical crypto
classes). See `examples/good-proguard-rules.pro`.

## Як доповідати

```
[obfuscation/proguard-rules-not-empty] ERROR
  app/proguard-rules.pro:1
  isMinifyEnabled=true but proguard-rules.pro contains only template comments (<N> non-comment lines).
  Fix: add -keep rules for at least: critical-classes from .claude/CLAUDE.md, Hilt entry points, kotlinx.serialization @Serializable classes.
  See: examples/good-proguard-rules.pro
```

## Виключення

Жодних. If you don't need keep rules, set `isMinifyEnabled = false`.
```

- [ ] **Step 3: Create `rules/obfuscation/crypto-classes-keep-rules-present.md`**

Write `/Users/mac/CodeReviewSystem/rules/obfuscation/crypto-classes-keep-rules-present.md`:

```markdown
---
id: obfuscation/crypto-classes-keep-rules-present
severity: error
category: obfuscation
applies-to:
  - app/proguard-rules.pro
since: "1.0.0"
---

# Critical crypto classes are covered by `-keep` rules

## Чому це важливо

When `isMinifyEnabled = true`, R8 may rename classes/methods used
reflectively by your decryption layer (e.g., Cipher transformation
strings built at runtime, helper objects accessed via simpleName, or
classes loaded by `Class.forName`). Renaming silently breaks decryption,
the app can't bootstrap (splash hangs, endpoint never resolves), and the
crash is hard to reproduce locally without a release build.

## Що перевірити

1. Take the `critical-classes` list from `.claude/CLAUDE.md` (already
   resolved by the obfuscation-auditor's procedure).
2. For each entry (a glob like `com.example.app.crypto.**`), check
   that `app/proguard-rules.pro` contains at least one `-keep` (or
   `-keep class`, `-keepclassmembers`, `-keepclasseswithmembers`)
   rule whose pattern covers it.
3. The pattern must use `**` (deep wildcard) for `**` globs, or `*`
   for shallow ones, matching the glob's intent.

## Як це виглядає у поганому проекті

```
# proguard-rules.pro
-dontwarn com.fancy.lib.**
# (no -keep for crypto classes despite critical-classes declaring them)
```

## Як це має виглядати

For `critical-classes` containing `com.example.app.core.crypto.**`:

```
# Keep crypto layer (R8 must not rename — runtime reflection on class names)
-keep class com.example.app.core.crypto.** { *; }
```

## Як доповідати

```
[obfuscation/crypto-classes-keep-rules-present] ERROR
  app/proguard-rules.pro
  No -keep rule covers critical-classes pattern: <pattern>
  Fix: add `-keep class <pattern> { *; }` (and consider `-keepclassmembers` if you only need members).
  See: examples/good-proguard-rules.pro
```

## Виключення

Жодних. If a class is in `critical-classes`, it must be kept.
```

- [ ] **Step 4: Create `rules/obfuscation/seed-keys-not-plain-string.md`**

Write `/Users/mac/CodeReviewSystem/rules/obfuscation/seed-keys-not-plain-string.md`:

```markdown
---
id: obfuscation/seed-keys-not-plain-string
severity: warning
category: obfuscation
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "1.0.0"
---

# Crypto seeds are not plain compile-time strings

## Чому це важливо

This rule overlaps with `security/no-hardcoded-secrets` but is scoped
specifically to **the seed/key feeding your in-app obfuscation** —
because security treats it as a secrets issue, while obfuscation treats
it as an *effectiveness* issue. A plain seed string makes ALL of your
encrypted endpoints/parameters trivial to decrypt. So the rule fires
even when `security/no-hardcoded-secrets` is suppressed.

## Що перевірити

1. Search files matching `sensitive-files` (from project's
   `.claude/CLAUDE.md`).
2. Detect a top-level/object-level `val` or `const val` whose:
   a. name contains `seed`, `key`, `salt` (case-insensitive), AND
   b. value is a plain `String` or `ByteArray` literal of ≥16 chars.
3. Detect "junk-char" obfuscation that constructs a String from a
   `charArrayOf(...)` with hand-picked indices (pattern `charArrayOf(`
   followed by `buildString` or `StringBuilder` indexing). This is
   reversible in seconds and provides false security.

## Як це виглядає у поганому проекті

```kotlin
val USER_SEED: ByteArray = "K9mT4Xq2Zp7Lw1R8Ys5Nv6Hd3Fa0BcJu".toByteArray()

private fun getTransformation(): String {
    val junk = charArrayOf('x','A','1','E','!','S',/* ... */)
    return buildString { append(junk[1]); append(junk[3]); /* ... */ }
}
```

## Як це має виглядати

Seed material loaded at runtime from outside the APK (NDK, KeyStore-
bound, server-derived after attestation). At minimum for MVP, kept in
`BuildConfig` from local `gradle.properties` so it isn't in source.

## Як доповідати

```
[obfuscation/seed-keys-not-plain-string] WARNING
  <file>:<line>
  Plain-string seed/key in compile-time constant: <name>.
  Fix: move out of source. NDK or KeyStore for production; BuildConfig from gradle.properties as a starting point.
  See: examples/good-proguard-rules.pro (commentary on "what -keep cannot save")
```

## Виключення

Дозволено через `accepted-risks`, тільки якщо seed свідомо public
(наприклад, public-key fingerprint, не secret). Тоді обґрунтування
обов'язкове.
```

- [ ] **Step 5: Verify**

```bash
cd /Users/mac/CodeReviewSystem
for f in agents/obfuscation-auditor.md rules/obfuscation/*.md; do
  test -f "$f" || { echo "MISSING: $f"; exit 1; }
  head -1 "$f" | grep -q "^---$" || { echo "BAD FRONTMATTER: $f"; exit 1; }
done
echo OK
```

Expected: `OK`.

- [ ] **Step 6: Commit**

```bash
git add agents/obfuscation-auditor.md rules/obfuscation/
git commit -m "feat(obfuscation): add obfuscation-auditor agent and 3 starter rules"
```

---

## Task 6: Style auditor agent + 3 rules

**Files:**
- Create: `agents/style-auditor.md`
- Create: `rules/style/kotlin-naming-conventions.md`
- Create: `rules/style/compose-stable-parameters.md`
- Create: `rules/style/hilt-no-field-injection.md`

- [ ] **Step 1: Create `agents/style-auditor.md`**

Same structure as `security-auditor.md` and `obfuscation-auditor.md` (Tasks 4–5). Replace category-specific text:

- Frontmatter `name: style-auditor`, description mentions Kotlin idioms, Compose recomposition pitfalls, Hilt usage.
- Procedure step 1: read `rules/style/*.md`.
- Procedure step 3: do not need `critical-classes`. Just `accepted-risks`.
- Output heading: `## Style audit`.
- Add this paragraph: "Style is the lowest-severity audit. Default to `info` over `warning` over `error` when uncertain. Avoid double-flagging code already addressed by IDE inspections (e.g., unused import) — Android Studio handles those."

- [ ] **Step 2: Create `rules/style/kotlin-naming-conventions.md`**

Write `/Users/mac/CodeReviewSystem/rules/style/kotlin-naming-conventions.md`:

```markdown
---
id: style/kotlin-naming-conventions
severity: info
category: style
applies-to:
  - app/src/main/java/**/*.kt
since: "1.0.0"
---

# Kotlin naming conventions

## Чому це важливо

Inconsistent naming makes a multi-author codebase harder to read.
Project review explicitly checks against the Kotlin coding conventions
(camelCase functions, PascalCase classes, SCREAMING_SNAKE_CASE for
top-level `const val`, no Hungarian-notation prefixes). Issues here
are usually quick fixes; they cluster in code that was machine-
generated or copied from a different ecosystem.

## Що перевірити

1. Top-level `const val` declarations: name should be `SCREAMING_SNAKE_CASE`.
   Flag if camelCase or PascalCase.
2. Function names: `camelCase`. Flag PascalCase functions
   (except `@Composable` functions, which are PascalCase by convention).
3. Class names: `PascalCase`.
4. Object/companion-object property names that hold class references:
   `camelCase`.
5. Avoid Hungarian-notation prefixes (`mFoo`, `sBar`).

## Як це виглядає у поганому проекті

```kotlin
const val maxCount = 5                  // should be MAX_COUNT
fun ProcessOrder() = ...                // should be processOrder (not @Composable)
class user_repository                   // should be UserRepository
val mService: Service = ...             // drop the `m` prefix
```

## Як це має виглядати

```kotlin
const val MAX_COUNT = 5
fun processOrder() = ...
class UserRepository
val service: Service = ...
```

## Як доповідати

```
[style/kotlin-naming-conventions] INFO
  <file>:<line>
  <kind> "<name>" violates Kotlin naming convention (expected <expected-form>).
  Fix: rename to <suggested>.
  See: https://kotlinlang.org/docs/coding-conventions.html#naming-rules
```

## Виключення

Жодних. Конвенцію можна порушувати тільки через `@Suppress` на
конкретному оголошенні з reason — який також буде відображено у звіті
як info.
```

- [ ] **Step 3: Create `rules/style/compose-stable-parameters.md`**

Write `/Users/mac/CodeReviewSystem/rules/style/compose-stable-parameters.md`:

```markdown
---
id: style/compose-stable-parameters
severity: warning
category: style
applies-to:
  - app/src/main/java/**/*.kt
since: "1.0.0"
---

# Composable parameters should be stable to enable skipping

## Чому це важливо

Jetpack Compose skips a Composable on recomposition only if all of its
parameters are "stable" (primitive, `@Stable`, `@Immutable`, or
provably unchanged). When a Composable receives a `MutableList`,
`MutableState` (instead of its value), or a function reference created
inline, Compose recomposes it on every parent invalidation. In a
gameplay loop or a list with hundreds of items this measurably tanks
frame rate.

## Що перевірити

1. Find every function annotated `@Composable`.
2. For each non-primitive parameter, check whether its declared type
   is a known stable type (List<X> → unstable; ImmutableList → stable;
   data class → stable iff all properties stable; classes annotated
   `@Stable` or `@Immutable` → stable).
3. Flag composables that take 2+ unstable parameters or any unstable
   collection parameter (`List`, `Map`, `Set`).
4. For lambdas: flag `() -> Unit` parameters used inside `LazyColumn`
   `items {}` blocks where the lambda is created inline at the call
   site (causes recomposition every parent recomposition).

## Як це виглядає у поганому проекті

```kotlin
@Composable
fun ScoreList(scores: List<Score>, onClick: (Score) -> Unit) {
    LazyColumn { items(scores) { Row(it, onClick) } }
}

// caller:
ScoreList(viewModel.scores, onClick = { viewModel.select(it) })   // lambda recreated each recomposition
```

## Як це має виглядати

```kotlin
@Composable
fun ScoreList(
    scores: ImmutableList<Score>,
    onClick: (Score) -> Unit
) { ... }

// caller — hoist the lambda:
val onClick = remember(viewModel) { { score: Score -> viewModel.select(score) } }
ScoreList(viewModel.scoresImmutable, onClick)
```

## Як доповідати

```
[style/compose-stable-parameters] WARNING
  <file>:<line>
  @Composable "<name>" takes unstable parameter <param>: <type>.
  Fix: change to ImmutableList/PersistentList, or annotate the type @Immutable, or hoist the function reference via remember.
  See: https://developer.android.com/jetpack/compose/performance/stability
```

## Виключення

Дозволено через `accepted-risks` для рідкісних композаблів, що
свідомо інвалідуються щотакта (наприклад, FPS-метр).
```

- [ ] **Step 4: Create `rules/style/hilt-no-field-injection.md`**

Write `/Users/mac/CodeReviewSystem/rules/style/hilt-no-field-injection.md`:

```markdown
---
id: style/hilt-no-field-injection
severity: warning
category: style
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "1.0.0"
---

# Prefer constructor injection over `@Inject` on fields

## Чому це важливо

Hilt supports both `@Inject` constructor parameters and `@Inject` on
mutable fields, but the latter forces the dependency to be `lateinit
var` (or `var = null`) — both are mutable, both invite NPEs on early
access (e.g., before `onCreate`), and both make tests harder (you
have to manually populate fields). Constructor injection produces
final fields, fails at construction time if a binding is missing, and
is naturally testable.

## Що перевірити

1. For each class annotated `@HiltAndroidApp`, `@AndroidEntryPoint`,
   `@HiltViewModel`, find every field with `@Inject`.
2. If the field type is something Hilt could inject via constructor
   (any `@Inject`-able), flag it. (Activities/Fragments/services are
   exempt because Android instantiates them — they must use field
   injection. Flag only ViewModels and plain classes.)

## Як це виглядає у поганому проекті

```kotlin
@HiltViewModel
class MyViewModel : ViewModel() {
    @Inject lateinit var repo: Repository
    @Inject lateinit var clock: Clock
}
```

## Як це має виглядати

```kotlin
@HiltViewModel
class MyViewModel @Inject constructor(
    private val repo: Repository,
    private val clock: Clock,
) : ViewModel()
```

## Як доповідати

```
[style/hilt-no-field-injection] WARNING
  <file>:<line>
  @Inject on field "<name>" in <class> (a Hilt component that supports constructor injection).
  Fix: move to constructor parameters. Activities/Fragments/Services may keep field injection.
  See: https://dagger.dev/hilt/quick-start
```

## Виключення

Дозволено для класів, що ініціалізуються Android-системою
(Activity/Fragment/Service/BroadcastReceiver/ContentProvider/Application).
```

- [ ] **Step 5: Verify**

```bash
cd /Users/mac/CodeReviewSystem
for f in agents/style-auditor.md rules/style/*.md; do
  test -f "$f" || { echo "MISSING: $f"; exit 1; }
  head -1 "$f" | grep -q "^---$" || { echo "BAD FRONTMATTER: $f"; exit 1; }
done
echo OK
```

Expected: `OK`.

- [ ] **Step 6: Commit**

```bash
git add agents/style-auditor.md rules/style/
git commit -m "feat(style): add style-auditor agent and 3 starter rules"
```

---

## Task 7: Orchestrator agent

**Files:**
- Create: `agents/orchestrator.md`

- [ ] **Step 1: Create `agents/orchestrator.md`**

Write `/Users/mac/CodeReviewSystem/agents/orchestrator.md`:

````markdown
---
name: orchestrator
description: Top-level Android Review orchestrator. Validates project root, dispatches 3 sub-agents in parallel, collects reports, performs cross-cutting analysis, formats the final report, and saves it as both markdown and Google-Docs-friendly text. Read-only.
tools: [Read, Glob, Grep, Bash, Task]
---

You are the **android-review orchestrator**.

## Procedure (follow exactly)

### 1. Validate project root

- Check that `app/build.gradle.kts` OR `app/build.gradle` exists in the
  current working directory.
- If neither exists, abort with this message and do nothing else:
  ```
  This is not an Android project root. Expected app/build.gradle(.kts) — not found.
  Did you cd to the project root before launching claude?
  ```

### 2. Read project context

- Try to read `.claude/CLAUDE.md` from the project root.
- Track CLAUDE.md status as one of: `found ✓`, `missing ⚠️`,
  `partially parseable ⚠️`.
- If found, parse:
  - `## project-id` (one non-comment line)
  - `## expected-values` (key:value lines)
  - `## critical-classes` (bullet list)
  - `## sensitive-files` (bullet list)
  - `## accepted-risks` (lines `<rule-id>: <reason>`; skip lines starting with `#`)
- If a section is unparseable, mark CLAUDE.md status as
  `partially parseable ⚠️` and skip that section.

### 3. Determine project-id

- If `## project-id` is set, use it.
- Else, fall back to the directory basename (`pwd | xargs basename`).
- Normalize to lowercase kebab-case (replace spaces and `.` with `-`,
  strip leading/trailing dashes).

### 4. Dispatch sub-agents IN PARALLEL

Use the `Task` tool to launch three sub-agents in a single message
(all three Task calls in one assistant turn — this is critical for
parallelism):

- `style-auditor`
- `security-auditor`
- `obfuscation-auditor`

Pass each agent the parsed `accepted-risks` (and `critical-classes`
for obfuscation-auditor) as part of its prompt context.

### 5. Collect results

- Each sub-agent returns one markdown report per the format their
  agent file specifies.
- If a sub-agent's tool call errors or times out, record under
  `## ⚠️ Agent failures` with name and reason. Do not retry. Verdict
  becomes `INCOMPLETE`.

### 6. Cross-cutting analysis

After all three reports are collected, scan them for these patterns
(MVP set; M2 will add more):

- **Exported component not -keep'd:** if security-auditor reports
  `security/exported-component-without-permission` and the named
  component class does NOT appear under any `-keep` in
  `app/proguard-rules.pro`, emit a cross-cutting `error` finding
  noting that R8 may rename the class and intent-filter resolution
  will fail at runtime.

For each cross-cutting finding, format as:

```
[cross/<short-id>] ERROR|WARNING
  <relevant files>
  <one-paragraph explanation>
  Fix: <combined fixer>.
```

### 7. Compute verdict

- Collect all severities across all sub-reports + cross-cutting.
- `READY` — 0 errors, 0 warnings.
- `READY WITH WARNINGS` — 0 errors, ≥1 warning.
- `NOT READY` — ≥1 error.
- `INCOMPLETE` — at least one sub-agent failed.

### 8. Format final report

Render exactly the structure of spec §7.1:

- Title `# Android Review report — <project-id>`
- Header (Date, Plugin version, Project, CLAUDE.md status)
- `## Summary` table (Errors/Warnings/Info/Skipped per category + Total)
- `**Verdict:**` line
- `## 🔴 Errors`, `## 🟡 Warnings`, `## ℹ️ Info` sections combining
  all sub-reports
- `## 🔗 Cross-cutting findings`
- `## ⚠️ Agent failures` (only if any)
- `## Skipped rules`
- `## Run details` (per-agent wall-clock if available, plus total)

### 9. Save outputs

Use Bash to manipulate files in the **project's** `.claude/reports/`
directory (NOT the plugin's). Steps:

```bash
mkdir -p .claude/reports/archive
TS=$(date +%Y-%m-%d-%H%M)
PID="<project-id>"
# Archive existing
[ -f ".claude/reports/${PID}-android-review.md" ] && \
  mv ".claude/reports/${PID}-android-review.md" \
     ".claude/reports/archive/${PID}-${TS}.md"
[ -f ".claude/reports/${PID}-android-review.gdoc.txt" ] && \
  mv ".claude/reports/${PID}-android-review.gdoc.txt" \
     ".claude/reports/archive/${PID}-${TS}.gdoc.txt"
```

Then write two files:
- `.claude/reports/<project-id>-android-review.md` — the markdown
  report verbatim.
- `.claude/reports/<project-id>-android-review.gdoc.txt` — the same
  report transformed per spec §7.3:
  - `# `, `## `, `### ` headings → UPPERCASE + blank line
  - markdown tables → tab-separated plain rows
  - inline code in backticks → leave as-is
  - emoji severity markers → keep
  - `[text](url)` → `text (url)`
  - no html, no markup

### 10. Print final report to terminal

Print the markdown report directly. Then print:

```
Saved:
  .claude/reports/<project-id>-android-review.md
  .claude/reports/<project-id>-android-review.gdoc.txt
```

## Hard constraints

- Read-only on the project. The only Bash operations permitted are:
  `mkdir -p .claude/reports/archive`, `mv` of existing report files
  into `archive/`, `date`, `pwd`, `basename`. No `rm`, no edits to
  project source.
- If a sub-agent returns malformed output, include it verbatim under
  the appropriate section and add a note to `## Skipped rules`. Never
  fabricate findings to fill a category.
````

- [ ] **Step 2: Verify file structure**

```bash
cd /Users/mac/CodeReviewSystem
test -f agents/orchestrator.md && head -1 agents/orchestrator.md | grep -q "^---$" && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add agents/orchestrator.md
git commit -m "feat(orchestrator): add orchestrator agent with parallel dispatch and report saving"
```

---

## Task 8: Slash commands

**Files:**
- Create: `commands/android-review.md`
- Create: `commands/android-review-style.md`
- Create: `commands/android-review-security.md`
- Create: `commands/android-review-obfuscation.md`

- [ ] **Step 1: Create `commands/android-review.md`**

Write `/Users/mac/CodeReviewSystem/commands/android-review.md`:

```markdown
---
description: Run a full Android Review on the current project (style + security + obfuscation + cross-cutting analysis). Saves report to .claude/reports/.
---

# /android-review

Run a complete Android code review on the project at the current
working directory.

## What this does

1. Validates that you are at the root of an Android project
   (looks for `app/build.gradle(.kts)`).
2. Reads `.claude/CLAUDE.md` if present (project-id, expected-values,
   critical-classes, sensitive-files, accepted-risks).
3. Dispatches three sub-agents in parallel:
   - **style-auditor** — Kotlin idioms, Compose recomposition, Hilt usage
   - **security-auditor** — manifest, permissions, cleartext, secrets
   - **obfuscation-auditor** — ProGuard/R8 rules vs critical classes
4. Performs cross-cutting analysis (e.g., exported component not -keep'd).
5. Saves a dual-format report to `.claude/reports/<project-id>-android-review.md`
   and `.claude/reports/<project-id>-android-review.gdoc.txt`.

## Usage

```bash
cd <android-project-root>
claude
/android-review
```

## Read-only safety

This command is read-only on your project. The plugin denies write
tools at the harness level — it cannot modify your code, no matter what.

---

Run the **orchestrator** agent now.

permissions:
  deny:
    - Edit
    - Write
    - "Bash(rm:*)"
    - "Bash(git:*)"
    - "Bash(curl:*)"
    - "Bash(wget:*)"
  allow:
    - Read
    - Glob
    - Grep
    - Task
    - "Bash(find:*)"
    - "Bash(cat:*)"
    - "Bash(ls:*)"
    - "Bash(mkdir:*)"
    - "Bash(mv:*)"
    - "Bash(date:*)"
    - "Bash(pwd:*)"
    - "Bash(basename:*)"
```

- [ ] **Step 2: Create `commands/android-review-security.md`**

Write `/Users/mac/CodeReviewSystem/commands/android-review-security.md`:

```markdown
---
description: Run only the security auditor on the current Android project. Faster than /android-review when you want a focused security pass.
---

# /android-review-security

Run only the security audit on the project at the current working directory.

## When to use

- Pre-release security pass without waiting for style/obfuscation.
- Verifying a security fix.
- Iterating on security rules during plugin development.

## Differences from /android-review

- No orchestrator, no cross-cutting analysis.
- Output goes to terminal only — NOT saved to `.claude/reports/`.
- Faster (one sub-agent instead of three).

## Usage

```bash
cd <android-project-root>
claude
/android-review-security
```

---

Run the **security-auditor** agent directly on the current working directory.
The agent must still read `.claude/CLAUDE.md` for `accepted-risks`.

permissions:
  deny:
    - Edit
    - Write
    - "Bash(rm:*)"
    - "Bash(git:*)"
    - "Bash(curl:*)"
    - "Bash(wget:*)"
  allow:
    - Read
    - Glob
    - Grep
    - "Bash(find:*)"
    - "Bash(cat:*)"
    - "Bash(ls:*)"
```

- [ ] **Step 3: Create `commands/android-review-obfuscation.md`**

Same structure as `android-review-security.md` (Step 2). Replace:
- title and description references to security → obfuscation
- "Run the **security-auditor**" → "Run the **obfuscation-auditor**"
- mention that this agent additionally reads `critical-classes`.

- [ ] **Step 4: Create `commands/android-review-style.md`**

Same structure as `android-review-security.md` (Step 2). Replace:
- references to security → style
- "Run the **security-auditor**" → "Run the **style-auditor**"
- description: "Run only the style auditor (Kotlin/Compose/Hilt idioms)."

- [ ] **Step 5: Verify**

```bash
cd /Users/mac/CodeReviewSystem
for f in commands/*.md; do
  test -f "$f" || { echo "MISSING: $f"; exit 1; }
  head -1 "$f" | grep -q "^---$" || { echo "BAD FRONTMATTER: $f"; exit 1; }
  grep -q "deny:" "$f" || { echo "MISSING permissions.deny in $f"; exit 1; }
done
echo OK
```

Expected: `OK`.

- [ ] **Step 6: Commit**

```bash
git add commands/
git commit -m "feat(commands): add 4 slash commands with read-only permission denylists"
```

---

## Task 9: Examples

**Files:**
- Create: `examples/good-proguard-rules.pro`

- [ ] **Step 1: Create `examples/good-proguard-rules.pro`**

Write `/Users/mac/CodeReviewSystem/examples/good-proguard-rules.pro`:

```proguard
# Good ProGuard rules — minimal, working baseline for an Android Kotlin/Compose/Hilt app.
# Adjust the package roots to match your project; see comments inline.

# ---- Crash readability ----
# Keep line numbers so stacktraces are useful, but rename source files for size.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ---- Hilt / Dagger ----
-keep,allowobfuscation,allowshrinking class dagger.hilt.** { *; }
-keep,allowobfuscation,allowshrinking class * extends dagger.hilt.android.internal.managers.ViewComponentManager$FragmentContextWrapper

# ---- kotlinx.serialization ----
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class * {
    *** Companion;
}
-keepclasseswithmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}

# ---- Project: critical classes (replace package roots with yours) ----
# These classes are accessed reflectively by your decryption layer.
# R8 must NOT rename them.
# Pull this list from .claude/CLAUDE.md `critical-classes`.
-keep class com.example.app.core.crypto.** { *; }
-keep class com.example.app.data.model.** { *; }

# ---- Activities (intent-filter resolution by name) ----
-keep class com.example.app.ui.activity.MainActivity { *; }

# ---- Compose runtime markers ----
# Compose handles its own keep rules via its compiler plugin; do not duplicate.

# ---- What -keep cannot save ----
# A plain-string AES seed in source is decompilable in seconds regardless of
# any keep rule. Move seeds out of compile-time constants — see the rules
# obfuscation/seed-keys-not-plain-string and security/no-hardcoded-secrets.
```

- [ ] **Step 2: Verify**

```bash
cd /Users/mac/CodeReviewSystem
test -f examples/good-proguard-rules.pro && \
  grep -q "Hilt" examples/good-proguard-rules.pro && \
  grep -q "kotlinx.serialization" examples/good-proguard-rules.pro && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add examples/good-proguard-rules.pro
git commit -m "feat(examples): add good-proguard-rules.pro reference"
```

---

## Task 10: Documentation

**Files:**
- Create: `docs/how-to-add-a-rule.md`
- Create: `docs/smoke-test.md`

- [ ] **Step 1: Create `docs/how-to-add-a-rule.md`**

Write `/Users/mac/CodeReviewSystem/docs/how-to-add-a-rule.md`:

```markdown
# How to add a rule

## TL;DR

1. `cp rules/_template.md rules/<category>/<your-slug>.md`
2. Fill the 5 frontmatter fields.
3. Fill the 6 body sections (Чому → Що перевірити → Поганий приклад →
   Хороший приклад → Як доповідати → Виключення).
4. Bump plugin minor version in `.claude-plugin/plugin.json` and add a
   line to `CHANGELOG.md`.
5. PR. Smoke-test against `Juice-Master-Factory` and `Joker-Speed-Seven`
   per `docs/smoke-test.md` before merge.

## Choosing the right severity

- **error** — blocks release. Use only if the rule corresponds to a
  hard requirement (Play policy, certain crash, leaked secret).
- **warning** — must review and either fix or accept. Default for
  best-practices.
- **info** — observation; doesn't change verdict. Use for style nits
  or "consider doing X".

## `applies-to` patterns

- Use globs relative to the project root (e.g., `app/src/main/**/*.kt`).
- Be **narrow**. The agent uses this for pre-filtering — wide patterns
  cost tokens and slow the run.
- For manifest rules, target `app/src/main/AndroidManifest.xml`
  exactly.

## When to use "Жодних" in `## Виключення`

Use literal `Жодних` (or `None`) when the rule:
- corresponds to a Google Play hard requirement, OR
- corresponds to a certain runtime crash, OR
- there is a built-in legitimate workaround at the source level
  (e.g., scoped `network_security_config.xml`).

Otherwise, document a narrow exception path.

## Anti-patterns when writing rules

- Don't write rules that overlap silently with another rule. If a
  finding could trigger two rules, pick one as the canonical.
- Don't let `## Що перевірити` reference project specifics. The rule
  must work across all your apps.
- Don't bury the fix in prose. The fix must appear in the
  `## Як доповідати` template explicitly.
- Don't add rules that require dynamic analysis (e.g., "the app makes
  fewer than N HTTP requests during cold start"). MVP is static-only.
```

- [ ] **Step 2: Create `docs/smoke-test.md`**

Write `/Users/mac/CodeReviewSystem/docs/smoke-test.md`:

```markdown
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
```

- [ ] **Step 3: Verify**

```bash
cd /Users/mac/CodeReviewSystem
test -f docs/how-to-add-a-rule.md && test -f docs/smoke-test.md && echo OK
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add docs/how-to-add-a-rule.md docs/smoke-test.md
git commit -m "docs: add rule-authoring guide and manual smoke-test plan"
```

---

## Task 11: Set up `.claude/CLAUDE.md` in two real Android projects

**Files:**
- Create: `~/StudioProjects/Juice-Master-Factory/.claude/CLAUDE.md`
- Modify: `~/StudioProjects/Juice-Master-Factory/.gitignore` (append one line)
- Create: `~/StudioProjects/Joker-Speed-Seven/.claude/CLAUDE.md`
- Modify: `~/StudioProjects/Joker-Speed-Seven/.gitignore` (append one line)

This is the only task that touches files outside the plugin repo. Each
project gets its `CLAUDE.md` so smoke-tests can run.

- [ ] **Step 1: Create CLAUDE.md for Juice-Master-Factory**

```bash
mkdir -p ~/StudioProjects/Juice-Master-Factory/.claude
```

Write `~/StudioProjects/Juice-Master-Factory/.claude/CLAUDE.md`:

```markdown
# Project context for Claude Code

Android casual game, Kotlin + Jetpack Compose + Hilt. Splash queries a
remote endpoint via Ktor, then either gameplay or a WebView landing
flow. Encrypted endpoint strings live under `core/decrypt/`.

---

# Android Review configuration

## project-id

juice-master-factory

## expected-values

applicationId: com.thinkplay.tp3g
namespace: com.fruity.juicemasterfactory
minSdk: 26
targetSdk: 36

## critical-classes

- com.fruity.juicemasterfactory.core.decrypt.**
- com.fruity.juicemasterfactory.data.model.**
- com.fruity.juicemasterfactory.data.datasource.**

## sensitive-files

- app/src/main/java/com/fruity/juicemasterfactory/core/decrypt/**
- app/src/main/java/com/fruity/juicemasterfactory/data/datasource/**

## accepted-risks

# (empty — populate after first /android-review run)

## rule-overrides

# (R3 placeholder — leave empty for M1.)
```

- [ ] **Step 2: Append `.claude/reports/` to Juice's `.gitignore`**

If `~/StudioProjects/Juice-Master-Factory/.gitignore` does not contain
the line `.claude/reports/`, append it:

```bash
grep -qxF '.claude/reports/' ~/StudioProjects/Juice-Master-Factory/.gitignore \
  || echo -e '\n# Claude Code Android Review reports\n.claude/reports/' \
     >> ~/StudioProjects/Juice-Master-Factory/.gitignore
```

- [ ] **Step 3: Create CLAUDE.md for Joker-Speed-Seven**

```bash
mkdir -p ~/StudioProjects/Joker-Speed-Seven/.claude
```

Write `~/StudioProjects/Joker-Speed-Seven/.claude/CLAUDE.md`:

```markdown
# Project context for Claude Code

Android arcade game, Kotlin + Jetpack Compose + Hilt + SQLDelight +
Voyager. Tap-target gameplay (7 / Joker cards). Splash uses a custom
AES helper to decrypt remote endpoint strings, then dispatches to
gameplay or a policy WebView.

---

# Android Review configuration

## project-id

joker-speed-seven

## expected-values

applicationId: org.fortheloss.st
namespace: org.fortheloss.st
minSdk: 26
targetSdk: 36

## critical-classes

- org.fortheloss.st.settings.crypto.**
- org.fortheloss.st.settings.settings.**
- org.fortheloss.st.data.splash.launch.**
- org.fortheloss.st.database.**

## sensitive-files

- app/src/main/java/org/fortheloss/st/settings/crypto/**
- app/src/main/java/org/fortheloss/st/settings/settings/UrlConf.kt
- app/src/main/java/org/fortheloss/st/data/splash/launch/**

## accepted-risks

# (empty — populate after first /android-review run)

## rule-overrides

# (R3 placeholder — leave empty for M1.)
```

- [ ] **Step 4: Append `.claude/reports/` to Joker's `.gitignore`**

```bash
grep -qxF '.claude/reports/' ~/StudioProjects/Joker-Speed-Seven/.gitignore \
  || echo -e '\n# Claude Code Android Review reports\n.claude/reports/' \
     >> ~/StudioProjects/Joker-Speed-Seven/.gitignore
```

- [ ] **Step 5: Verify**

```bash
test -f ~/StudioProjects/Juice-Master-Factory/.claude/CLAUDE.md && \
  test -f ~/StudioProjects/Joker-Speed-Seven/.claude/CLAUDE.md && \
  grep -q '.claude/reports/' ~/StudioProjects/Juice-Master-Factory/.gitignore && \
  grep -q '.claude/reports/' ~/StudioProjects/Joker-Speed-Seven/.gitignore && \
  echo OK
```

Expected: `OK`.

- [ ] **Step 6: Commit (in plugin repo only — these external project changes are not committed here)**

These files live in OTHER repositories (`Juice-Master-Factory` and
`Joker-Speed-Seven`). They are NOT part of the plugin repo. Optionally
commit each to its own project repo as separate commits with message
`chore(claude): add android-review configuration`. Do not stage them
into the plugin repo.

---

## Task 12: End-to-end smoke-test

This task is a **manual run** of all 5 scenarios from `docs/smoke-test.md`
against the live system. No new files are created. Output is observed
and compared.

- [ ] **Step 1: Install the plugin locally for testing**

Two options — pick one:

**A. Add the local repo as a marketplace.**

```bash
claude
/plugin marketplace add file:///Users/mac/CodeReviewSystem
/plugin install android-review@local-marketplace
```

**B. Use the marketplace command on the GitHub repo (after pushing).**

```bash
git remote add origin git@github.com:<owner>/CodeReviewSystem.git
git push -u origin main
# Then in claude:
/plugin marketplace add github:<owner>/CodeReviewSystem
/plugin install android-review@<owner>-marketplace
```

For M1 verification, option A is fine.

- [ ] **Step 2: Run S1 (Juice full run)**

Per `docs/smoke-test.md` §S1. Capture the full report. Verify:
- Verdict line is `NOT READY`.
- Both `.md` and `.gdoc.txt` files appeared in
  `~/StudioProjects/Juice-Master-Factory/.claude/reports/`.
- The `.gdoc.txt` file looks reasonable when pasted into a Google Doc
  (do this manually — open a test Google Doc, paste, eyeball headings
  and tables).

If any expected error is missing — STOP. Diagnose: open the relevant
agent file and the relevant rule file, identify the gap, fix in the
plugin, repeat S1.

- [ ] **Step 3: Run S2 (Joker full run)**

Per §S2. Same verification.

- [ ] **Step 4: Run S3 (targeted obfuscation pass)**

Per §S3.

- [ ] **Step 5: Run S4 (not in Android project)**

Per §S4.

- [ ] **Step 6: Run S5 (no CLAUDE.md)**

Per §S5. Don't forget to restore the file at the end.

- [ ] **Step 7: Record results in CHANGELOG.md**

```bash
cd /Users/mac/CodeReviewSystem
```

Edit `CHANGELOG.md` — append `Smoke-test passed: S1 ✓ S2 ✓ S3 ✓ S4 ✓ S5 ✓`
under the `## [1.0.0] — 2026-04-29` heading. If any scenario failed and
you fixed it, also note that.

- [ ] **Step 8: Commit smoke-test results**

```bash
git add CHANGELOG.md
git commit -m "chore: record M1 smoke-test pass on Juice + Joker"
```

---

## Task 13: Tag v1.0.0

- [ ] **Step 1: Tag the release**

```bash
cd /Users/mac/CodeReviewSystem
git tag -a v1.0.0 -m "M1 release: orchestrator + 3 sub-agents + 9 rules + smoke-tested on Juice and Joker"
```

- [ ] **Step 2: Verify tag and history**

```bash
git tag --list
git log --oneline
```

Expected: `v1.0.0` listed; commit history shows the 12 task commits.

- [ ] **Step 3: (Optional) Push to remote**

If a remote repo exists:

```bash
git push origin main --tags
```

If not yet set up — skip; this can be done later when the GitHub repo is created.

---

## Self-Review (executed during plan authoring; outcome recorded here)

**1. Spec coverage check.** Walked the spec section by section:

- §1 Context, §2 Scope — informational, no tasks needed.
- §3 Architecture (orchestrator + 3 sub-agents, R2 separation, read-only) — Tasks 4–8.
- §4 Repo structure — Tasks 1–10 cover all directories except `examples/good-android-manifest.xml` (deferred, not strictly required by any rule in M1; will appear in M2 if a manifest-shape rule needs a reference).
- §5 Rule format (frontmatter + 6 body sections) — Task 2 documents it; Tasks 4–6 produce 9 conforming rules.
- §6 Project CLAUDE.md format — Task 3 (template + example), Task 11 (live in two real projects).
- §7 Final report structure (Summary → Errors → Warnings → Info → Cross-cutting → Skipped → Run details + 4 verdicts) — Task 7 (orchestrator) implements the rendering.
- §8 Save behavior (Format B + N3 archive) — Task 7 (orchestrator §9).
- §9 Error handling (5 cases) — Task 7 covers cases 1, 3, 4; Tasks 4/5/6 cover case 2 (invalid frontmatter); case 5 is informational.
- §10 Permissions/security — Task 8 (commands' deny lists).
- §11 Smoke-test plan — Task 10 (`docs/smoke-test.md`), Task 12 (executes it).
- §12 Versioning — Task 1 (CHANGELOG seed), Task 13 (tag).
- §13 Open items — out of scope for M1 by design.
- §14 Decisions log — informational, no task.

**Gap addressed inline:** spec calls for `examples/good-android-manifest.xml`. Removed from M1 file list — none of the 9 MVP rules cite it; no false promise. Will appear when a rule referencing it is added in M2.

**2. Placeholder scan.** Scanned the plan for the patterns from "No Placeholders":
- No "TBD" / "TODO" / "fill in details".
- No "add appropriate error handling" / "handle edge cases".
- No "Write tests for the above" without code.
- One "Same structure as security-auditor.md" pattern is used for `obfuscation-auditor.md`, `style-auditor.md`, and three sibling slash-command files. Acceptable: the *original* `security-auditor.md` content is fully written in Task 4 and explicitly referenced; the structural reuse is bounded ("frontmatter + Procedure + output heading + hard constraints"). Implementer reads the source once and applies obvious edits.

**3. Type consistency.** Identifiers:
- `project-id` (kebab-case) used uniformly across spec, agents, and CLAUDE.md examples.
- `critical-classes`, `sensitive-files`, `accepted-risks` — section names match across template (Task 3), live CLAUDE.md (Task 11), agent prompts (Tasks 4, 5, 7).
- `<project-id>-android-review.md` filename pattern matches between orchestrator (Task 7 §9), spec §8.2, and smoke-test (Task 10).
- `READY` / `READY WITH WARNINGS` / `NOT READY` / `INCOMPLETE` — match between orchestrator (§7 Step 7), spec §7.2, and smoke-test §S1 expectation.

No contradictions found.

---

## Execution handoff (decision required)

**Plan complete and saved to** `docs/plans/2026-04-29-android-review-mvp-plan.md`.

Two execution options:

**1. Subagent-Driven (recommended)** — A fresh subagent per task, two-stage review between tasks, fast iteration. Best when each task is sufficiently self-contained (this plan: yes).

**2. Inline Execution** — Execute tasks in this same session using `superpowers:executing-plans`. Batch execution with checkpoints. Slower but lets you see/redirect every step.

**Which approach?**
