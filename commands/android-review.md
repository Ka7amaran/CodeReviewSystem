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
`cat` for heredoc, `date`, `pwd`, `basename`, `echo`) are allowed
because the orchestrator must save report files. The orchestrator's
procedure restricts those writes to `.claude/reports/` — this is
**procedural** (not enforced at the harness level). If you observe
the orchestrator writing outside `.claude/reports/`, please report
it as a bug.

---

## Dispatching the agent

The plugin root path (resolved at command render time):

PLUGIN_ROOT_RESOLVED: !`echo "${CLAUDE_PLUGIN_ROOT:-/Users/mac/CodeReviewSystem}"`

Use the `Task` tool with `subagent_type: orchestrator` and the prompt body
below. Substitute the value of `PLUGIN_ROOT_RESOLVED` from the line above
into the `PLUGIN_ROOT:` field of the prompt — do NOT pass any literal
`${...}` placeholder, and do NOT pass an empty value.

Prompt to send via the Task tool:

```
PLUGIN_ROOT: <value of PLUGIN_ROOT_RESOLVED above>

Run a complete Android code review on the project at the current working directory. Follow your system prompt's procedure exactly.
```

After the orchestrator returns its markdown report, print it verbatim
to the user.
