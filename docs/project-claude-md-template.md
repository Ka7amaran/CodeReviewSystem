# Project `.claude/CLAUDE.md` template

Place this file at the root of an Android project that will be reviewed
with `/android-review`. It serves two purposes simultaneously:

1. Project context auto-loaded by Claude Code.
2. Machine-readable declarations parsed by the orchestrator.

## Template (copy-paste, then fill the required sections)

```markdown
# Project context for Claude Code

(Free-form short description of the project. Optional.)

---

# Android Review configuration

## project-id

<short-kebab-case-id>

## expected-values

applicationId: <com.example.app>
namespace: <com.example.app>
minSdk: 26
targetSdk: 36

## critical-classes

- <com.example.app.crypto.**>
- <com.example.app.data.model.**>

## sensitive-files

- <app/src/main/java/com/example/app/crypto/**>
- <app/src/main/java/com/example/app/data/api/**>

## accepted-risks

# Lines starting with `#` are comments and are IGNORED by the orchestrator.
# To actually suppress a rule, write a non-commented line:
#   <rule-id>: <reason why this risk is accepted>
# Example:
# security/exported-component-without-permission: DeepLinkActivity validates host/scheme before dispatching; deliberately public

## rule-overrides

# (R3 placeholder — leave empty for M1.)
```

## Section reference

| Section            | Purpose                                                            | Required? |
|--------------------|--------------------------------------------------------------------|-----------|
| `project-id`       | Human-readable id used in report titles and filenames.             | Yes       |
| `expected-values`  | Optional baseline validation of `applicationId`/`namespace`/SDK.   | No        |
| `critical-classes` | Glob patterns that must be covered by `-keep` rules. Modern stacks (Hilt + kotlinx.serialization + Compose + Ktor) usually don't need this — consumer-rules from each library cover it automatically. | Optional  |
| `sensitive-files`  | Glob patterns where the security agent searches harder. Empty = agent scans every Kotlin/Java file. | Optional  |
| `accepted-risks`   | `<rule-id>: <reason>` — silences a rule if its "Виключення" allows.| Optional  |
| `rule-overrides`   | Reserved for future R3 per-project rule parameter overrides (unparsed in M1). | Leave empty |

**Most projects can leave both `critical-classes` and `sensitive-files`
empty.** The plugin handles missing/empty gracefully — the obfuscation
auditor falls back to heuristic auto-detection, and the security
auditor scans all source files. Fill these sections only when you know
your project genuinely needs them (see the TODO comments in the
generated CLAUDE.md scaffold for concrete reflection-use-site
examples).

## What happens if `.claude/CLAUDE.md` is missing

The plugin does not fail. Agents fall back to defaults:
- `expected-values` checks are skipped.
- `critical-classes` are heuristically detected by name patterns
  (`*crypto*`, `*decrypt*`, `*Cipher*`, `*Auth*`, `Key*`).
- `sensitive-files` defaults to all Kotlin files; expect more noise.
- `accepted-risks` is empty.

The report header reflects the missing file with `CLAUDE.md: missing ⚠️`.

## What to gitignore

Reports are generated under `.claude/reports/` inside the project.
Add this to your project's `.gitignore`:

```
.claude/reports/
```

`.claude/CLAUDE.md` itself is **not** gitignored — it is configuration,
and changes to it must be PR-reviewed by your team.
