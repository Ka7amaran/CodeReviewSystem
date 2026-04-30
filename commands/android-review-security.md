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

## Note on PLUGIN_ROOT

This command injects `Plugin root: ${CLAUDE_PLUGIN_ROOT}` into the
security-auditor's prompt. The agent aborts immediately if this
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

Step 2 — dispatch the **security-auditor** sub-agent:

Use the `Task` tool with `subagent_type: security-auditor` and this prompt body
(substitute `<plugin-root>` with the actual value captured in step 1
— do NOT pass the literal string `${CLAUDE_PLUGIN_ROOT}`):

```
Plugin root: <plugin-root>

Run a security audit on the Android project at the current working directory. Follow your system prompt's procedure exactly. Return the markdown report only.
```

Step 3 — after the agent returns its markdown report, print it
verbatim to the user.
