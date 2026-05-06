# Rule file schema (v2.0 — functional)

Every rule lives in `rules/<category>/<rule-id-slug>.md` where `category`
is one of `flow`, `webview`, `crypto`. The filename slug must match the
`id` field after the `/`.

## Frontmatter (5 mandatory + 1 optional fields)

```yaml
---
id: <category>/<slug>                  # e.g. flow/organic-routing-critical
severity: critical | suspicious | observation   # see § Severity below
category: flow | webview | crypto      # duplicates first id segment
applies-to:                            # OPTIONAL hint for the agent's attention
  - <pattern>                          # NOT a hard pre-filter — agent does dataflow tracing
since: "<semver>"                      # plugin version that introduced the rule
requires-project-type: with-attribution | no-attribution   # OPTIONAL; if set, rule auto-skips on non-matching projects
---
```

## Body (6 mandatory sections, each `## Heading`)

1. **`## Інваріант`** — what behavior must hold at runtime. The
   contract the rule defends. 1-3 sentences.
2. **`## Як перевірити`** — dataflow-trace recipe for the agent.
   How to verify the invariant by reading code (which symbols to
   look for, which call chains to follow, which file types to read).
   This is NOT a grep recipe — it's a reasoning recipe.
3. **`## Як виглядає поломка`** — minimal example of the broken
   behavior (Kotlin/XML/JSON snippet).
4. **`## Як виглядає правильно`** — minimal example of correct
   behavior.
5. **`## Як доповідати`** — exact finding template (Ukrainian body
   for human-readable text; rule-id and severity stay English as
   machine-readable tokens).
6. **`## Виключення`** — when the user can silence the rule via
   `accepted-deviations` in `.claude/CLAUDE.md`. Use the literal
   text `Жодних` if the rule cannot be silenced (reserved for
   `flow/organic-routing-critical`).

## Severity scheme

- **`critical`** — broken invariant causes runtime issue or violates
  the user-defined contract; report verdict becomes `🔴 НЕ ГОТОВО`.
- **`suspicious`** — non-blocking heuristic, worth a glance.
- **`observation`** — informational, never blocks.

## Categories

- **`flow/`** — application-startup and runtime behavior (UUID,
  push init, attribution, routing, redirect method).
- **`webview/`** — WebView/CustomTabs configuration and host
  Activity requirements.
- **`crypto/`** — POST-data encoding pattern (file paths NOT
  pinned; only the pattern).
- **`perf/`** — performance and pitfall observations
  (`severity: observation` only). Surfaces actionable
  improvements: startup-blocking patterns, WebView UX/perf
  pitfalls, runtime-decrypt cost. NEVER blocks the verdict —
  these are advisory, not contracts.

Style/security/obfuscation categories from v1.x are deleted —
they don't map to functional flows.

## How the agent applies rules

1. Discover all `*.md` files in `rules/<category>/` (skip files
   starting with `_`).
2. Read project's `.claude/CLAUDE.md` for `project-type` and
   `accepted-deviations` (and `redirect-method` for the redirect
   rule).
3. For each rule:
   - If `requires-project-type` is set and doesn't match → skip,
     surface under "Пропущені перевірки" with reason
     "project-type: <X> required, current: <Y>".
   - If `id` is in `accepted-deviations` AND the rule's
     `## Виключення` allows suppression → skip, surface under
     "Пропущені перевірки" with the user's verbatim reason.
   - Otherwise → consult context7 MCP for currency
     (`mcp__plugin_context7_context7__query-docs`) before flagging.
   - Apply the `## Як перевірити` recipe via dataflow tracing.
   - For each violation → emit a finding using the
     `## Як доповідати` template (Ukrainian body).
   - For each rule that PASSED → list under "Перевірені інваріанти".
4. Group findings by emitted severity (`critical` →
   `🔴 Критичні баги функціональної логіки`, `suspicious` →
   `⚠️ Підозрілі патерни`, `observation` → `ℹ️ Спостереження`).
