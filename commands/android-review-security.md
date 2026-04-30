---
description: Run only the security auditor on the current Android project. Faster than /android-review when you want a focused security pass.
---

# /android-review-security

Run only the security audit on the project at the current working
directory.

## When to use

- Pre-release security pass without waiting for style/obfuscation.
- Verifying a security fix.
- Iterating on security rules during plugin development.

## Differences from /android-review

- No orchestrator, no cross-cutting analysis.
- Output goes to terminal only — NOT saved to `.claude/reports/`.
- Faster (one sub-agent instead of three).

## Usage

```
cd <android-project-root>
claude
/android-review-security
```

---

## Dispatching the agent

The plugin root path (resolved at command render time):

PLUGIN_ROOT_RESOLVED: !`echo "${CLAUDE_PLUGIN_ROOT:-/Users/mac/CodeReviewSystem}"`

Use the `Task` tool with `subagent_type: security-auditor` and the prompt
body below. Substitute the value of `PLUGIN_ROOT_RESOLVED` from the line
above into the `Plugin root:` field — do NOT pass any literal
`${...}` placeholder, and do NOT pass an empty value.

Prompt to send via the Task tool:

```
Plugin root: <value of PLUGIN_ROOT_RESOLVED above>

Run a security audit on the Android project at the current working directory. Follow your system prompt's procedure exactly. Return the markdown report only.
```

After the agent returns its markdown report, print it verbatim to the user.
