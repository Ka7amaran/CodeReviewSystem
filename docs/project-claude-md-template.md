# Project `.claude/CLAUDE.md` template (v2.10)

Place this file at the root of an Android project that will be reviewed
with `/android-review`. It serves two purposes:
1. Project context auto-loaded by Claude Code.
2. Machine-readable declarations parsed by the `functional-validator`
   agent.

As of v2.2.0, the file declares only **2 fields**. Four legacy
fields (`landing-mechanism`, `redirect-method`, `backend-domain`,
`link-storage`) are now detected from code automatically by the
validator's Stage 0 — no manual declaration needed.

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

| Detected value      | Method                                                                                                                                                                                       |
|---------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `landing-mechanism` | Searches for `WebView(`/`AndroidView { factory = { WebView` vs `CustomTabsIntent`.                                                                                                           |
| `redirect-method`   | Catalog 7.1–7.5: `addWebMessageListener`, `onConsoleMessage`, `shouldOverrideUrlLoading` + custom scheme, `onReceivedTitle`, `onPageFinished/Started`. Novel mechanisms → OBSERVATION (v2.7.0+). |
| `backend-domain`    | First POST endpoint URL in the non-organic branch — literal or `<encrypted-at-rest>`.                                                                                                        |
| `link-storage`      | `tracker` (UUID + backend resolves redirect each launch) vs `final` (WebView callback saves last-URL into SharedPreferences/DataStore/Room/File). CustomTabs → always `tracker`. Since v2.10.0. |

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
