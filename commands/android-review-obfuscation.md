---
description: Run only the obfuscation auditor on the current Android project. Focused on ProGuard/R8 rules and critical-class coverage.
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

# /android-review-obfuscation

Run only the obfuscation audit on the project at the current working
directory.

## When to use

- Verifying ProGuard/R8 keep-rule coverage before a release build.
- Checking that all critical classes (crypto, auth, token handling) are
  protected from renaming/removal by minification.
- Iterating on obfuscation rules during plugin development.

## What this checks

The obfuscation-auditor reads your project's `## critical-classes` list
from `.claude/CLAUDE.md`. If that section is missing or empty, it
auto-detects potential critical classes by scanning `app/src/main/java/**`
for names matching patterns like `crypto`, `cipher`, `encrypt`, `auth`,
`token`, `key`, etc. (top 20 matches). It then checks whether each
critical class is covered by a `-keep` rule in `app/proguard-rules.pro`.

## Differences from /android-review

- No orchestrator, no cross-cutting analysis.
- Output goes to terminal only — NOT saved to `.claude/reports/`.
- Faster (one sub-agent instead of three).

## Usage

```
cd <android-project-root>
claude
/android-review-obfuscation
```

## Note on PLUGIN_ROOT

This command injects `Plugin root: ${CLAUDE_PLUGIN_ROOT}` into the
obfuscation-auditor's prompt. The agent aborts immediately if this
variable is not set. If you see the error:

```
ERROR: plugin root was not supplied by the caller. Cannot locate rules.
```

it means `${CLAUDE_PLUGIN_ROOT}` was not expanded at dispatch time —
check that Claude Code's plugin infrastructure set the variable before
running this command.

---

Now: dispatch the **obfuscation-auditor** sub-agent. The agent REQUIRES
the plugin root path in its prompt.

Use the `Task` tool with `subagent_type: obfuscation-auditor` and this
prompt:

```
Plugin root: ${CLAUDE_PLUGIN_ROOT}

Run an obfuscation audit on the Android project at the current working
directory. Follow your system prompt's procedure exactly. Return the
markdown report only.
```

After the agent returns its report, print it verbatim to the user.
