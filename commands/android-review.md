---
description: "v2.0 — Run a full Android Review of the current project — functional validation against the team's contract. Saves report to .claude/reports/."
---

# /android-review (v2.0)

Run a complete functional review on the project at the current working
directory.

## What this does

1. Validates that you are at the root of an Android project (looks for
   `app/build.gradle(.kts)`).
2. Auto-detects plugin root (Claude Code 2.1.x doesn't expose
   `${CLAUDE_PLUGIN_ROOT}` to slash commands).
3. Reads `.claude/CLAUDE.md` (5 fields: project-type, landing-mechanism,
   redirect-method, backend-domain, accepted-deviations).
4. Dispatches the `functional-validator` sub-agent. The agent applies
   8 functional rules via dataflow tracing.
5. Saves the report as `.claude/reports/<project-id>-android-review.md`,
   archiving the previous one to `archive/<project-id>-<timestamp>.md`.
6. Prints a compact summary in the terminal.

## Usage

```
cd <android-project-root>
claude
/android-review
```

---

## Step 1 — Validate Android project root

Use `Glob` (not Bash) to check for `app/build.gradle.kts` or
`app/build.gradle` in cwd.

If neither exists, your ENTIRE response must be exactly the two lines
below — verbatim, in English, no preamble, no postamble, no
translation, no follow-up:

```
This is not an Android project root. Expected app/build.gradle(.kts) — not found.
Did you cd to the project root before launching claude?
```

After printing, STOP. Do NOT call any further tools. Do NOT translate.
Do NOT scan filesystem for nearby Android projects.

## Step 2 — Locate plugin root (runtime auto-detection)

Use Bash:

```
ls -td "$HOME/.claude/plugins/cache/android-review-marketplace/android-review/"*/ 2>/dev/null | head -1
```

Take the first line of stdout (the most recently-installed version's
directory). Strip trailing slash. Bind as `PLUGIN_ROOT`.

If output is empty, abort with:

```
Cannot locate the android-review plugin's installation under $HOME/.claude/plugins/cache/android-review-marketplace/. Reinstall via /plugins → Marketplaces → Update marketplace.
```

## Step 3 — Determine project-id

- If `.claude/CLAUDE.md` exists and `## project-id` parses to a
  non-empty token, use that value.
- Otherwise, fall back to `pwd | xargs basename`, lowercase,
  whitespace/underscores → `-`, collapse multiple `-`. (`xargs` may
  trigger one-time permission prompt — acceptable.)

## Step 4 — Dispatch the functional-validator

Use the `Task` tool with `subagent_type: functional-validator` and this
prompt body. Substitute the discovered `PLUGIN_ROOT`:

```
Plugin root: <PLUGIN_ROOT>

Run a full functional Android review on the project at the current working directory. Follow your system prompt's procedure exactly. Return the markdown report only.
```

Wait for the agent's return. The agent returns a markdown report whose
top-level heading is `## Android Review`.

## Step 5 — Read project metadata for the report header

Use `Read` on `<PLUGIN_ROOT>/.claude-plugin/plugin.json` and parse
`version` field.

Use Bash `date "+%Y-%m-%d %H:%M"` for the report date (capture as
`REPORT_DATE`, use once).

## Step 6 — Compose the final report (Ukrainian)

Take the agent's output and wrap it in the report skeleton:

```
# Android Review — <project-id>

**Дата:** <REPORT_DATE>  •  **Версія плагіна:** <plugin-version>
**Тип проєкту:** <project-type>  •  **Лендинг:** <landing-mechanism>  •  **Метод редіректу:** <redirect-method or "n/a">

## Вердикт: <verdict>

---

<entire agent output, with "## Android Review" stripped — only its subsections>

---
```

Verdict computation:
- 0 critical AND 0 suspicious → `✅ ГОТОВО`.
- 0 critical AND ≥1 suspicious → `⚠️ З ЗАСТЕРЕЖЕННЯМИ`.
- ≥1 critical → `🔴 НЕ ГОТОВО`.

## Step 7 — Save report (with N3 archive)

Compute archive timestamp ONCE: `date "+%Y-%m-%d-%H%M"` → `TS`.

Sequence (Bash):

```
mkdir -p .claude/reports/archive
[ -f ".claude/reports/<project-id>-android-review.md" ] && \
  mv ".claude/reports/<project-id>-android-review.md" \
     ".claude/reports/archive/<project-id>-<TS>.md"
```

Use `Write` to create `.claude/reports/<project-id>-android-review.md`
with the full report from Step 6.

## Step 8 — Terminal summary (NOT the full report)

Print ONLY this compact summary as your final assistant message:

```
# Android Review — <project-id>

**Дата:** <REPORT_DATE>  •  **Плагін:** <plugin-version>
**Тип:** <project-type>  •  **Лендинг:** <landing-mechanism>  •  **Редірект:** <redirect-method or "n/a">

**Вердикт:** <verdict>

**Критичні:** <count>
**Підозрілі:** <count>
**Спостереження:** <count>
**Пропущено правил:** <count>

**Збережено:** `.claude/reports/<project-id>-android-review.md`
```

If the save step fails, replace the `**Збережено:**` line with:
`**Збережено:** ПОМИЛКА — <reason>`. Never retry. Never print the
full report as a fallback.

## Mandatory dispatch discipline

Do NOT do any of the following:
- Skip steps because "this doesn't look like an Android project" — Step 1
  handles that case.
- Translate the abort message in Step 1 (verbatim English).
- Decide on your own to scan `~/StudioProjects/` or any other directory.
- Ask the user "which project to check?".
- Reply with anything before dispatching the agent (Step 4).
