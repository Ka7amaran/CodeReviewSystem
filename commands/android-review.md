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

Run from your Android project's root directory:

```
cd <android-project-root>
claude
/android-review
```

## Read-only safety

This command does not modify your project source code. `Edit` and
mutating shell commands (`rm`, `git`, `curl`, `wget`, `npm`, `pip`,
`brew`) are denied at the harness level — the agent literally cannot
execute them, regardless of input.

`Write` and a small set of file-system Bash verbs (`mkdir`, `mv`,
`date`, `pwd`, `basename`, `echo`) are allowed because the orchestrator
must save report files. The orchestrator's procedure restricts those
writes to `.claude/reports/` — this is **procedural** (not enforced at
the harness level). If you observe writes outside `.claude/reports/`,
please report it as a bug.

---

## Plugin root

The plugin root path (hardcoded for local install; revisit when published to GitHub):

PLUGIN_ROOT_RESOLVED: /Users/mac/CodeReviewSystem

Use this value below wherever `<PLUGIN_ROOT>` appears.

---

## Orchestration procedure (you, the slash-command runner, execute this directly)

You are NOT an orchestrator sub-agent. The previous architecture
attempted to put orchestration into a `Task`-dispatched sub-agent, but
Claude Code 2.1.x forbids `Task` calls from inside a sub-agent (`Task
is not available inside subagents`). Therefore the slash-command body
itself drives the orchestration. You ARE the orchestrator. Do NOT
attempt to dispatch an `orchestrator` sub-agent — that agent is
deprecated.

You DO have `Task` available because you are running at the top level
of the slash command, not inside a sub-agent. Use `Task` to dispatch
the three category auditors as siblings.

Follow the steps below exactly, in order.

### Step 0 — Mandatory dispatch discipline

Do NOT do ANY of the following:
- Skip steps because "this doesn't look like an Android project" — Step 1
  handles that case explicitly. Run Step 1 first.
- Translate the abort message in Step 1 (it must be verbatim English).
- Decide on your own to scan `~/StudioProjects/` or any other directory
  for projects.
- Ask the user "which project to check?".

### Step 1 — Validate the project root

Use `Glob` (not Bash) to check for the existence of either
`app/build.gradle.kts` or `app/build.gradle` in the current working
directory.

If neither file exists, your ENTIRE response to the user must be
exactly the two lines below — verbatim, in English, no preamble, no
postamble, no translation, no paraphrasing, no follow-up question:

```
This is not an Android project root. Expected app/build.gradle(.kts) — not found.
Did you cd to the project root before launching claude?
```

After printing those two lines, STOP. Do NOT call any further tools.
Do NOT generate a report. Do NOT save anything. Your turn ends.

**Negative examples (DO NOT produce output that looks like these):**

- ❌ "Поточна директорія не є коренем Android-проєкту…" (translated; forbidden).
- ❌ "This is not… Якщо хочете, скажіть де лежить проєкт." (follow-up; forbidden).
- ❌ Message followed by a `Bash(ls /Users/mac/StudioProjects/)` tool call (post-abort tool use; forbidden).

✅ GOOD: Exactly the two-line English message, then nothing.

### Step 2 — Read project context (`.claude/CLAUDE.md`)

Try to read `.claude/CLAUDE.md` from the project root using the `Read`
tool. There are three states; the one chosen drives the
`**CLAUDE.md:**` header line in step 8:

- **`found ✓`** — file present, all six expected sections (`project-id`,
  `expected-values`, `critical-classes`, `sensitive-files`,
  `accepted-risks`, `rule-overrides`) parse cleanly.
- **`missing ⚠️`** — file does not exist or is unreadable.
- **`partially parseable ⚠️`** — file exists but at least one section is
  malformed. Skip the malformed section silently (do not fail), and in the
  header note which section was unparseable, e.g.
  `CLAUDE.md: partially parseable ⚠️ (expected-values section unparseable, ignored)`.

An empty section (header present but body contains only whitespace or
`#`-prefix comments) is considered to PARSE CLEANLY with an empty
value. Only structurally malformed sections (e.g., a list where bullets
are not `- ` prefixed, or `<key>: <value>` lines with broken syntax)
trigger `partially parseable ⚠️` status.

You will use:
- `project-id` in step 3.
- `accepted-risks`, `critical-classes`, `sensitive-files` are read by
  sub-agents themselves; you only need to determine that the sections parse.
- `rule-overrides` is an R3 placeholder and is intentionally ignored.

Do NOT read project source code yourself. Your only project-level
reads are `.claude/CLAUDE.md`, `app/build.gradle*` (existence check via
Glob), `app/src/main/AndroidManifest.xml` (cross-cutting), and
`app/proguard-rules.pro` (cross-cutting). All rule-driven source
analysis is performed by sub-agents.

### Step 3 — Determine `project-id`

- If `.claude/CLAUDE.md` was found and the `## project-id` section parsed
  to a non-empty token, use that value.
- Otherwise, fall back to the basename of cwd, normalized to lowercase
  kebab-case. Use Bash:

  ```
  pwd | xargs basename
  ```

  Then transform the result to lowercase, replace any whitespace and
  underscores with `-`, and collapse multiple `-` into one. (`xargs` may
  trigger a permission prompt on first use — that is acceptable.)

Hold this value as `<project-id>` for the rest of the procedure.

### Step 4 — Dispatch three sub-agents IN PARALLEL

You MUST dispatch all three sub-agents in a SINGLE assistant message
containing three `Task` tool calls. Do NOT call them sequentially.
Issuing them in one message is what makes them run in parallel.

Each Task call must include `Plugin root: <PLUGIN_ROOT>` in its prompt
(substituting the actual value from `PLUGIN_ROOT_RESOLVED` above).
Sub-agents abort if `Plugin root:` is missing.

Use this exact prompt template for each sub-agent (substitute the
category):

```
Plugin root: <PLUGIN_ROOT>

Run a full <category> audit on the Android project at the current working directory. Follow your system prompt's procedure exactly. Return the markdown report only.
```

Three Task tool calls in ONE message:
- `subagent_type: style-auditor`, prompt with category `style`.
- `subagent_type: security-auditor`, prompt with category `security`.
- `subagent_type: obfuscation-auditor`, prompt with category `obfuscation`.

**Note (R2 separation):** each sub-agent re-reads the project's
`.claude/CLAUDE.md` itself. You do NOT forward parsed values into the
sub-agent prompts. This preserves the principle that rules and project
context are sub-agent inputs, not orchestrator state.

Record the wall-clock start time before dispatch and the wall-clock
end time after all three return. Per-agent wall-clock is the difference
if the runtime exposes it; otherwise omit per-agent times and report
only the total.

### Step 5 — Collect three sub-reports

Each sub-agent returns a markdown report whose top-level section is
one of `## Style audit`, `## Security audit`, `## Obfuscation audit`.
Capture each report verbatim. Do NOT retry any sub-agent.

A sub-agent is considered to have failed if any of these is true:
- the Task tool itself errored (timeout, unhandled exception);
- the returned text does not contain the expected `## <Category> audit`
  heading;
- the report is missing all four expected subsections (`Errors`,
  `Warnings`, `Info`, `Skipped rules`).

For each failure, record an entry in an internal `agent_failures` list
with the agent name and a one-line reason. If the sub-agent returned
malformed-but-partial output, KEEP the partial output verbatim so it
can be embedded in the appropriate section of the final report, and
note the partial nature under `## Skipped rules`.

If at least one failure exists, the verdict in step 7 will be
`INCOMPLETE`.

The `since: <semver>` frontmatter field of each rule (spec §9.5) is
checked by the SUB-AGENT, not by you. If a rule's `since` is newer
than the plugin version, the sub-agent skips it and lists it in its
own `### Skipped rules` subsection. Forward those entries to the final
report's `## Skipped rules` section unchanged.

### Step 6 — Cross-cutting analysis

For MVP, implement EXACTLY ONE cross-cutting check.

**`cross/exported-component-not-keep`** — fires only when:

1. The security sub-report contains at least one finding tagged with
   `[security/exported-component-without-permission]` (search the
   security report text for that exact bracketed tag), AND
2. For each such finding:
   - Extract the raw component name from the finding text. The security
     rule's `## Як доповідати` template emits `<component-tag> "<name>"`
     — `<name>` is what was in the manifest's `android:name` attribute,
     which is **almost always a relative form** (e.g., `.MainActivity`,
     `.push.PushService`).
   - Canonicalize the name to a fully-qualified class name (FQCN):
     a. If the raw name starts with `.`, prepend the manifest's
        `package=` attribute. Read it from
        `app/src/main/AndroidManifest.xml`.
     b. If the raw name contains no `.` at all, also prepend the
        package (relative single-segment names).
     c. If the raw name already contains one or more `.` segments
        without a leading `.`, treat it as already-FQCN.
   - Use the FQCN form in BOTH (i) the `-keep` pattern coverage check
     and (ii) the suggested fix in the cross-cutting finding.
   AND
3. That component class is NOT covered by any `-keep` pattern in
   `app/proguard-rules.pro`. To check coverage:
   - Read `app/proguard-rules.pro` (if absent, treat as empty — every
     component is uncovered).
   - For each `-keep`/`-keepclass`/`-keepclasseswithmembers` line,
     extract the class pattern (everything between `class` and the
     optional `{ ... }` or end-of-line). Patterns may use ProGuard
     glob syntax (`*`, `**`, `?`).
   - Match the component FQCN against each pattern using these
     equivalences: `**` matches any sequence including dots, `*`
     matches any sequence not containing `.`, `?` matches a single
     non-dot char.
   - If at least one pattern matches, the component IS covered.

For each component that triggers the check, emit ONE finding with this
exact format (severity `error`):

```
[cross/exported-component-not-keep] ERROR
  app/src/main/AndroidManifest.xml + app/proguard-rules.pro
  <component-name> is exported AND not covered by any -keep rule. After R8 minification the class may be renamed; the intent-filter resolution will then fail at runtime, causing crashes when external apps try to launch the component.
  Fix: add `-keep class <fqcn-of-component> { *; }` to app/proguard-rules.pro.
```

If the security sub-report contains no
`[security/exported-component-without-permission]` findings, the
cross-cutting findings list for this run is empty.

### Step 7 — Compute verdict

Aggregate all findings across the three sub-reports plus cross-cutting:

- Count `error`-severity findings → `errors_total`.
- Count `warning`-severity findings → `warnings_total`.
- Count `info`-severity findings → `info_total`.
- Count `Skipped rules` entries → `skipped_total`.

Verdict (apply the FIRST matching rule):

| Condition                                              | Verdict                |
|--------------------------------------------------------|------------------------|
| `agent_failures` is non-empty                          | `INCOMPLETE`           |
| `errors_total ≥ 1`                                     | `NOT READY`            |
| `errors_total == 0` AND `warnings_total ≥ 1`           | `READY WITH WARNINGS`  |
| `errors_total == 0` AND `warnings_total == 0`          | `READY`                |

`INCOMPLETE` takes precedence over `NOT READY` (a partial run with
errors is still `INCOMPLETE`).

### Step 8 — Format the final report

- Read the plugin version from `<PLUGIN_ROOT>/.claude-plugin/plugin.json`
  using the `Read` tool. Parse the JSON in your reasoning to extract
  the `version` field. Use that string verbatim in the
  `**Plugin version:**` header field.
- Compute the report-header date ONCE: run `date "+%Y-%m-%d %H:%M"`
  and bind it. Use this value in the `**Date:**` field. Do NOT
  recompute later.

Produce the report with this exact skeleton (substitute placeholders):

```
# Android Review report — <project-id>

**Date:** <YYYY-MM-DD HH:MM>
**Plugin version:** <semver-or-unknown>
**Project:** <absolute path of cwd>
**CLAUDE.md:** <found ✓ | missing ⚠️ | partially parseable ⚠️ (<sections>)>

---

## Summary

| Category    | Errors | Warnings | Info | Skipped |
|-------------|--------|----------|------|---------|
| Style       | <e>    | <w>      | <i>  | <s>     |
| Security    | <e>    | <w>      | <i>  | <s>     |
| Obfuscation | <e>    | <w>      | <i>  | <s>     |
| **Total**   | <E>    | <W>      | <I>  | <S>     |

**Verdict:** <READY | READY WITH WARNINGS | NOT READY | INCOMPLETE>

---

## 🔴 Errors (must fix)

(combined error-severity findings from all sub-reports + cross-cutting)

---

## 🟡 Warnings (recommended)

(combined warning-severity findings)

---

## ℹ️ Info

(combined info-severity findings)

---

## 🔗 Cross-cutting findings

(list of cross-cutting findings emitted in step 6, or `(none)`)

---

## ⚠️ Agent failures

(present ONLY if `agent_failures` is non-empty; one entry per failed
agent: name, reason, and any partial output verbatim)

---

## Skipped rules

(combined Skipped rules from all three sub-reports, deduplicated)

---

## Run details

- style-auditor:       <wall-clock or "n/a">, <rules-applied or "n/a"> rules applied, <findings-count> findings
- security-auditor:    <wall-clock or "n/a">, <rules-applied or "n/a"> rules applied, <findings-count> findings
- obfuscation-auditor: <wall-clock or "n/a">, <rules-applied or "n/a"> rules applied, <findings-count> findings
- orchestrator merge:  <X> cross-cutting findings
- Total wall-clock:    <wall-clock or "n/a">
```

Detailed rules for filling sections:

- **Per-category counts.** Parse each sub-report's `### Errors`,
  `### Warnings`, `### Info`, `### Skipped rules` subsections; count
  entries. A "finding entry" is a paragraph starting with a line
  matching this exact regex: `^\[[a-z0-9\-/]+\] (ERROR|WARNING|INFO)$`.
  Lines that don't match this anchor (truncated/malformed) are NOT
  counted toward `Errors`/`Warnings`/`Info`. Surface them under
  `## Skipped rules` with reason `malformed sub-report entry`.
  Cross-cutting findings count toward neither Style nor Security nor
  Obfuscation rows — they only contribute to the `**Total**` row and
  to the `## 🔗 Cross-cutting findings` section.
- **Sort order in `## 🔴 Errors`, `## 🟡 Warnings`, `## ℹ️ Info`.**
  Within each severity, sort by file path (lexicographic), then by
  line number (ascending).
  Location extraction protocol:
  - The location is on the SECOND non-blank line of the finding entry,
    immediately below the `[<rule-id>] <SEVERITY>` header.
  - Format: `  <file>:<line>` (two-space indent).
  - Special cases:
    - `<file>:0` (e.g., `crypto-classes-keep-rules-present` file-level
      finding) sorts as line 0 — first within that file.
    - Cross-cutting findings whose location line lists multiple files
      separated by ` + ` sort by the FIRST file's path, line 0.
    - Findings with no parseable location go last within their
      severity, in the order they appeared in the sub-report.
- **If a category has zero findings**, write `(none)` under that
  section heading.
- **Findings inclusion.** Do NOT rewrite findings — copy each one
  verbatim from the sub-reports (and from step 6 for cross-cutting).
  Cross-cutting `error`-severity findings appear in BOTH `## 🔴 Errors`
  AND `## 🔗 Cross-cutting findings`.
- **Skipped rules deduplication.** If the same `<rule-id>` appears in
  multiple sub-reports' Skipped sections, keep one entry, joining
  reasons with `; `.
- **Agent failures section.** Omit entirely if `agent_failures` is
  empty. Do NOT write `(none)` and do NOT include the heading.
- **No fabrication.** If a section has no content, write `(none)`
  (except `## ⚠️ Agent failures`, which is omitted entirely). Never
  invent findings to fill a section.
- **Run details fallback values:**
  - If wall-clock is not available from the runtime: write `n/a`.
  - If a sub-report does not surface the `rules applied` count: write
    `n/a`.
  - `findings-count` = the count from the regex above.

### Step 9 — Save outputs (Format B + N3 archive)

- Compute the archive timestamp ONCE at the start of step 9: run
  `date "+%Y-%m-%d-%H%M"` and bind it as `TS`. Use the SAME value for
  BOTH the `.md` archive `mv` AND the `.gdoc.txt` archive `mv`. Do NOT
  recompute between the two moves.
- Timestamp granularity is one minute. Two `/android-review` runs
  within the same minute will overwrite the previous archive entry.
  Acceptable for MVP.

Use `<project-id>` from step 3.

Sequence:

1. Ensure archive directory exists (Bash):
   ```
   mkdir -p .claude/reports/archive
   ```
2. If `.claude/reports/<project-id>-android-review.md` already exists,
   move it (Bash):
   ```
   mv .claude/reports/<project-id>-android-review.md .claude/reports/archive/<project-id>-<TS>.md
   ```
3. If `.claude/reports/<project-id>-android-review.gdoc.txt` already
   exists, move it (Bash):
   ```
   mv .claude/reports/<project-id>-android-review.gdoc.txt .claude/reports/archive/<project-id>-<TS>.gdoc.txt
   ```
4. Use the `Write` tool to create
   `.claude/reports/<project-id>-android-review.md` with the full
   markdown report from step 8.
5. Use the `Write` tool to create
   `.claude/reports/<project-id>-android-review.gdoc.txt` with the
   Google-Docs-friendly transformation of the markdown.

**Markdown → gdoc.txt conversion rules.** Apply in this order to the
exact text produced in step 8:

1. **Headings.** Replace any line matching `^#{1,3} (.*)$` with the
   captured text in UPPERCASE, followed by one blank line.
   `## Summary` → `SUMMARY` then blank line.
2. **Markdown tables.** Detect contiguous blocks where every line
   starts with `|`. Drop the alignment row (`|---|---|...`). For each
   remaining row, strip the leading and trailing `|`, split on `|`,
   trim each cell, and join cells with a single tab character (`\t`).
   Output one row per line. Add a blank line after the table.
3. **Markdown links.** Replace `[text](url)` with `text (url)`.
4. **Inline backticks.** Leave the backticks as-is. Google Docs
   renders them as plain text and that is acceptable.
5. **Bullets.** `- ` markdown bullets pass through as `- `. `*` and
   `+` markdown bullets are converted to `- ` for consistency. Do not
   introduce `• ` or other Unicode bullet characters.
6. **Horizontal rules.** Replace `---` lines with a single blank line.
7. **Bold/italic markup** (`**bold**`, `*italic*`). Strip the `**`
   and `*` markers; keep the inner text plain.
8. **Severity emoji** (`🔴`, `🟡`, `ℹ️`, `✓`, `❌`, `⚠️`). KEEP as-is.
9. **No HTML, no markdown markup other than bullets/numbers** in the
   output. Resulting file is plain UTF-8 text.

### Step 10 — Print and footer

After saving both files successfully, print the markdown report from
step 8 verbatim to the terminal (your final assistant message),
followed by exactly:

```

Saved:
  .claude/reports/<project-id>-android-review.md
  .claude/reports/<project-id>-android-review.gdoc.txt
```

(Note the leading blank line and two-space indentation.)

If the save step fails, still print the markdown report and append
`Saved: ERROR — <reason>` instead of the success footer. Never retry.

---

## Hard constraints

- **Read-only project source.** You must NEVER modify project source
  files. The only files you write are the two output reports under
  `.claude/reports/` (via `Write` tool). The only files you move are
  the previous reports into `.claude/reports/archive/` (via `mv`).
- **No project-source reads to formulate findings.** Your project-level
  reads are limited to `.claude/CLAUDE.md`, `app/build.gradle.kts`/
  `app/build.gradle` (existence check via Glob),
  `app/src/main/AndroidManifest.xml` (cross-cutting context),
  `app/proguard-rules.pro` (cross-cutting context). Sub-agents do all
  rule-driven source analysis.
- **No retry of failed sub-agents.** One attempt only.
- **No fabricated findings.** Never invent content to fill an empty
  section.
- **Parallel dispatch.** The three sub-agent Task tool calls MUST be
  issued in a single assistant message. Sequential calls are a bug.
- **Forward `Plugin root:` verbatim.** Each Task tool prompt MUST
  contain `Plugin root: <PLUGIN_ROOT>` so the sub-agent's procedure
  step 1 succeeds.
- **Cross-cutting trigger.** `cross/exported-component-not-keep` only
  fires when the security sub-report contains at least one
  `[security/exported-component-without-permission]` finding. Do NOT
  re-evaluate the manifest to decide whether components are exported.
- **Verdict precedence.** `INCOMPLETE` > `NOT READY` >
  `READY WITH WARNINGS` > `READY`.
- **Stable output.** Sort findings by file path then line number
  within each severity section. Identical inputs produce identical
  reports.
- **No partial writes.** Only after both files are written do you
  print the `Saved:` footer.
- **Hard-abort discipline (Step 1).** If the project root validation
  fails, emit ONLY the two-line English message and stop. No
  translation. No follow-up. No tool calls afterward.
