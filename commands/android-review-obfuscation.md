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

The plugin root path (resolved at command render time):

PLUGIN_ROOT_RESOLVED: !`echo "${CLAUDE_PLUGIN_ROOT:-/Users/mac/CodeReviewSystem}"`

Use the `Task` tool with `subagent_type: obfuscation-auditor` and the
prompt body below. Substitute the value of `PLUGIN_ROOT_RESOLVED` from
the line above into the `Plugin root:` field — do NOT pass any literal
`${...}` placeholder, and do NOT pass an empty value.

Prompt to send via the Task tool:

```
Plugin root: <value of PLUGIN_ROOT_RESOLVED above>

Run an obfuscation audit on the Android project at the current working directory. Follow your system prompt's procedure exactly. The agent additionally reads the project's `## critical-classes` section from .claude/CLAUDE.md if present. Return the markdown report only.
```

After the agent returns its markdown report, print it verbatim to the user.
