# Project `.claude/CLAUDE.md` template (v2.2)

Place this file at the root of an Android project that will be reviewed
with `/android-review`. It serves two purposes:
1. Project context auto-loaded by Claude Code.
2. Machine-readable declarations parsed by the `functional-validator`
   agent.

As of v2.2.0, the file declares only **2 fields**. Three v2.0/v2.1
fields (`landing-mechanism`, `redirect-method`, `backend-domain`) are
now detected from code automatically by the validator's Stage 0 — no
manual declaration needed.

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

## accepted-deviations

# rule-id: justification
```

## Section reference

| Section               | Purpose                                                                                           | Required?    |
|-----------------------|---------------------------------------------------------------------------------------------------|--------------|
| `project-id`          | Human-readable id used in report titles and filenames.                                            | Yes          |
| `project-type`        | `with-attribution` or `no-attribution` — controls whether attribution-flow rules apply.           | Yes          |
| `accepted-deviations` | `<rule-id>: <reason>` — silences a specific functional check with written justification.          | Optional     |

## Auto-detection from code (Stage 0)

The validator detects these from your project source on every run:

| Detected value      | Method                                                                                |
|---------------------|---------------------------------------------------------------------------------------|
| `landing-mechanism` | Searches for `WebView(`/`AndroidView { factory = { WebView` vs `CustomTabsIntent`.    |
| `redirect-method`   | Three signatures: `addWebMessageListener` (7.1), `onConsoleMessage` override (7.2), `shouldOverrideUrlLoading` + custom scheme (7.3). |
| `backend-domain`    | First POST endpoint URL in the non-organic branch — literal or `<encrypted-at-rest>`. |

Detected values appear in the report header marked `(виявлено)`.

## What happens if `.claude/CLAUDE.md` is missing

The plugin does NOT fail. The `functional-validator` agent uses
defaults: `project-type = with-attribution`, `accepted-deviations = ∅`.
Stage 0 detection still runs as normal. Report header notes the
missing file. Run `/android-review-init` to fix.

## What to gitignore

Reports go to `.claude/reports/`. Add this to your project's
`.gitignore`:

```
.claude/reports/
```

`.claude/CLAUDE.md` itself is NOT gitignored — it is configuration,
PR-reviewed by the team.
