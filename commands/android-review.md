---
description: Run a full Android Review on the current project (style + security + obfuscation + cross-cutting analysis). Saves report to .claude/reports/.
permissions:
  deny:
    - Edit
    - "Bash(rm:*)"
    - "Bash(git:*)"
    - "Bash(curl:*)"
    - "Bash(wget:*)"
    - "Bash(npm:*)"
    - "Bash(pip:*)"
    - "Bash(brew:*)"
  allow:
    - Read
    - Glob
    - Grep
    - Task
    - Write
    - "Bash(find:*)"
    - "Bash(cat:*)"
    - "Bash(ls:*)"
    - "Bash(mkdir:*)"
    - "Bash(mv:*)"
    - "Bash(date:*)"
    - "Bash(pwd:*)"
    - "Bash(basename:*)"
    - "Bash(echo:*)"
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

## Note on PLUGIN_ROOT

This command injects `PLUGIN_ROOT: ${CLAUDE_PLUGIN_ROOT}` into the
orchestrator's prompt. The orchestrator aborts immediately if this
variable is not set. If you see the error:

```
ERROR: PLUGIN_ROOT was not supplied by the slash-command wrapper.
```

it means `${CLAUDE_PLUGIN_ROOT}` was not expanded at dispatch time —
check that Claude Code's plugin infrastructure set the variable before
running this command.

---

## Dispatching the agent

Step 1 — resolve the plugin root via Bash:

Run: `echo "$CLAUDE_PLUGIN_ROOT"`. Capture stdout as `<plugin-root>`.

If the captured value is empty or the literal string `$CLAUDE_PLUGIN_ROOT`,
abort and tell the user:

> The Claude Code plugin runtime did not expose `CLAUDE_PLUGIN_ROOT`.
> The android-review plugin cannot run without it. Please report this
> to the plugin maintainer.

Step 2 — dispatch the **orchestrator** sub-agent:

Use the `Task` tool with `subagent_type: orchestrator` and this prompt body
(substitute `<plugin-root>` with the actual value captured in step 1
— do NOT pass the literal string `${CLAUDE_PLUGIN_ROOT}`):

```
PLUGIN_ROOT: <plugin-root>

Run a complete Android code review on the project at the current working directory. Follow your system prompt's procedure exactly.
```

Step 3 — after the agent returns its markdown report, print it
verbatim to the user.
