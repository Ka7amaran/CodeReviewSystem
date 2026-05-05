# Project `.claude/CLAUDE.md` template (v2.0)

Place this file at the root of an Android project that will be reviewed
with `/android-review`. It serves two purposes:
1. Project context auto-loaded by Claude Code.
2. Machine-readable declarations parsed by the `functional-validator`
   agent.

## Template

```markdown
# Project context for Claude Code

(Free-form short description, optional.)

---

# Android Review configuration

## project-id

<short-kebab-case-id>

## project-type

with-attribution    # or: no-attribution

## landing-mechanism

webview             # or: custom-tabs | none

## redirect-method

7.1 webMessageListener    # or: 7.2 consoleLog | 7.3 shouldOverrideUrlLoading

## backend-domain

https://example.store

## accepted-deviations

# rule-id: justification
```

## Section reference

| Section               | Purpose                                                                                           | Required?    |
|-----------------------|---------------------------------------------------------------------------------------------------|--------------|
| `project-id`          | Human-readable id used in report titles and filenames.                                            | Yes          |
| `project-type`        | `with-attribution` or `no-attribution` — controls whether attribution-flow rules apply.           | Yes          |
| `landing-mechanism`   | `webview`, `custom-tabs`, or `none` — controls which WebView/CustomTabs rules apply.              | Yes          |
| `redirect-method`     | `7.1` / `7.2` / `7.3` — which Privacy Policy → game redirect to verify. Leave empty if landing = none/custom-tabs. | Yes (if landing = webview) |
| `backend-domain`      | Production backend URL for attribution POST and WebView load.                                     | Yes (if project-type = with-attribution) |
| `accepted-deviations` | `<rule-id>: <reason>` — silences a specific functional check with written justification.          | Optional     |

## Auto-detection

`/android-review-init` auto-fills `project-type`, `landing-mechanism`,
and `backend-domain` from the project's gradle and source. The other
two fields (`redirect-method`, `accepted-deviations`) are TODO for the
human because they cannot be reliably guessed.

## What happens if `.claude/CLAUDE.md` is missing

The plugin does NOT fail. The `functional-validator` agent uses
defaults: `project-type = with-attribution`,
`landing-mechanism = webview`, empty `redirect-method`, empty
`backend-domain`, empty `accepted-deviations`. Report header notes the
missing file. Findings may be noisier without project context — run
`/android-review-init` to fix.

## What to gitignore

Reports go to `.claude/reports/`. Add this to your project's
`.gitignore`:

```
.claude/reports/
```

`.claude/CLAUDE.md` itself is NOT gitignored — it is configuration,
PR-reviewed by the team.
