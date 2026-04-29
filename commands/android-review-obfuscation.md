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
    - "Bash(echo:*)"
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

## Dispatching the agent

Step 1 — resolve the plugin root via Bash:

Run: `echo "$CLAUDE_PLUGIN_ROOT"`. Capture stdout as `<plugin-root>`.

If the captured value is empty or the literal string `$CLAUDE_PLUGIN_ROOT`,
abort and tell the user:

> The Claude Code plugin runtime did not expose `CLAUDE_PLUGIN_ROOT`.
> The android-review plugin cannot run without it. Please report this
> to the plugin maintainer.

Step 2 — dispatch the **obfuscation-auditor** sub-agent:

Use the `Task` tool with `subagent_type: obfuscation-auditor` and this prompt body
(substitute `<plugin-root>` with the actual value captured in step 1
— do NOT pass the literal string `${CLAUDE_PLUGIN_ROOT}`):

```
Plugin root: <plugin-root>

Run an obfuscation audit on the Android project at the current working directory. Follow your system prompt's procedure exactly. The agent additionally reads the project's `## critical-classes` section from .claude/CLAUDE.md if present. Return the markdown report only.
```

Step 3 — after the agent returns its markdown report, print it
verbatim to the user.
