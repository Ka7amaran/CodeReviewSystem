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

### Step 1 — Locate the plugin root (runtime auto-detection)

Claude Code 2.1.x does NOT expose `${CLAUDE_PLUGIN_ROOT}` to slash
commands. Discover the plugin's installation directory at runtime:

```
ls -td "$HOME/.claude/plugins/cache/android-review-marketplace/android-review/"*/ 2>/dev/null | head -1
```

Take the first line of stdout (the most recently-installed version's
directory). Strip any trailing slash. Bind as `PLUGIN_ROOT`.

If the command produced no output, abort with:

```
Cannot locate the android-review plugin's installation under $HOME/.claude/plugins/cache/android-review-marketplace/. Reinstall via /plugins → Marketplaces → Update marketplace.
```

### Step 2 — Dispatch the security-auditor

Use the `Task` tool with `subagent_type: security-auditor` and the
prompt below. Substitute the discovered `PLUGIN_ROOT` value into the
`Plugin root:` field.

Prompt:

```
Plugin root: <PLUGIN_ROOT>

Run a security audit on the Android project at the current working directory. Follow your system prompt's procedure exactly. Return the markdown report only.
```

After the agent returns, print its markdown report verbatim to the
user.
