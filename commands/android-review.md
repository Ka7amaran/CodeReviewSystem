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

This command is read-only on your project source. The plugin denies
write tools (`Edit`) and mutating shells at the harness level — it
cannot modify your code. The only file system writes are to
`.claude/reports/` (for the report files), via the `Write` tool.

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

Now: dispatch the **orchestrator** sub-agent. The orchestrator REQUIRES
the plugin root path to be supplied in its prompt — it aborts otherwise.

Use the `Task` tool with `subagent_type: orchestrator` and this prompt:

```
PLUGIN_ROOT: ${CLAUDE_PLUGIN_ROOT}

Run a complete Android code review on the project at the current
working directory. Follow your system prompt's procedure exactly.
```

After the orchestrator returns its markdown report, print it verbatim
to the user.
