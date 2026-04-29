---
description: Run only the style auditor on the current Android project. Kotlin/Compose/Hilt idioms.
permissions:
  deny:
    - Edit
    - Write
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
    - "Bash(find:*)"
    - "Bash(cat:*)"
    - "Bash(ls:*)"
    - "Bash(pwd:*)"
---

# /android-review-style

Run only the style audit on the project at the current working
directory.

## When to use

- Code style pass before submitting a PR.
- Verifying Kotlin idiom adherence, Compose recomposition hygiene, or
  Hilt usage patterns.
- Iterating on style rules during plugin development.

## Differences from /android-review

- No orchestrator, no cross-cutting analysis.
- Output goes to terminal only — NOT saved to `.claude/reports/`.
- Faster (one sub-agent instead of three).

## Usage

```
cd <android-project-root>
claude
/android-review-style
```

## Note on PLUGIN_ROOT

This command injects `Plugin root: ${CLAUDE_PLUGIN_ROOT}` into the
style-auditor's prompt. The agent aborts immediately if this variable
is not set. If you see the error:

```
ERROR: plugin root was not supplied by the caller. Cannot locate rules.
```

it means `${CLAUDE_PLUGIN_ROOT}` was not expanded at dispatch time —
check that Claude Code's plugin infrastructure set the variable before
running this command.

---

Now: dispatch the **style-auditor** sub-agent. The agent REQUIRES
the plugin root path in its prompt.

Use the `Task` tool with `subagent_type: style-auditor` and this
prompt:

```
Plugin root: ${CLAUDE_PLUGIN_ROOT}

Run a style audit on the Android project at the current working
directory. Follow your system prompt's procedure exactly. Return the
markdown report only.
```

After the agent returns its report, print it verbatim to the user.
