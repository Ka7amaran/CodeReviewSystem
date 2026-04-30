---
description: Run only the obfuscation auditor on the current Android project. Focused on ProGuard/R8 rules and critical-class coverage.
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

### Step 2 — Dispatch the obfuscation-auditor

Use the `Task` tool with `subagent_type: obfuscation-auditor` and the
prompt below. Substitute the discovered `PLUGIN_ROOT` value into the
`Plugin root:` field.

Prompt:

```
Plugin root: <PLUGIN_ROOT>

Run an obfuscation audit on the Android project at the current working directory. Follow your system prompt's procedure exactly. The agent additionally reads the project's `## critical-classes` section from .claude/CLAUDE.md if present. Return the markdown report only.
```

After the agent returns, print its markdown report verbatim to the
user.
