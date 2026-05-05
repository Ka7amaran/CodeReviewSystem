# How to add a rule (v2.0)

## TL;DR

1. `cp rules/_template.md rules/<category>/<your-slug>.md`
   where `<category>` is `flow`, `webview`, or `crypto`.
2. Fill the 5 mandatory frontmatter fields (+ `requires-project-type`
   if applicable).
3. Fill the 6 body sections (Інваріант / Як перевірити / Як виглядає
   поломка / Як виглядає правильно / Як доповідати / Виключення).
4. Bump plugin minor version in `.claude-plugin/plugin.json` and
   `marketplace.json`. Add a CHANGELOG line.
5. PR. Smoke-test against a real team project per `docs/smoke-test.md`
   before merge.

## Choosing the right severity

- **`critical`** — broken invariant causes runtime issue or violates
  the user-defined contract. Verdict becomes `🔴 НЕ ГОТОВО`. Reserve
  for hard contracts (e.g., `flow/organic-routing-critical`).
- **`suspicious`** — non-blocking heuristic, worth a glance. Default
  for most rules.
- **`observation`** — informational, never blocks.

## Choosing the right category

- **`flow/`** — runtime behavior on app startup or attribution
  (UUID, push init, attribution, routing, redirect method).
- **`webview/`** — WebView/CustomTabs configuration and host Activity.
- **`crypto/`** — POST-data encoding pattern (no path pinning).

If a rule doesn't fit these — reconsider whether it should be a static
rule at all. v2.0's philosophy is functional invariants, not generic
best practices.

## `requires-project-type`

Set to `with-attribution` for rules that only apply when attribution is
present (most `flow/` rules). Set to `no-attribution` for rules that
only apply for game-only builds (rare). Leave unset if the rule is
universal (most `webview/` and `crypto/` rules).

## When to use `Жодних` in `## Виключення`

Reserve `Жодних` for hard contracts that the team has decided cannot
be silenced via `accepted-deviations`. Currently this applies only to
`flow/organic-routing-critical` and `flow/uuid-persistence`.

For all other rules, document a narrow exception path with required
justification format.

## Anti-patterns when writing rules

- Don't pin to file paths or class names. The team's apps vary widely
  on structure.
- Don't pin to library versions or specific SDKs. Multiple SDKs may
  achieve the same functional outcome.
- Don't write `## Як перевірити` as a grep recipe. Write it as a
  reasoning recipe — what dataflow chains the agent should trace.
- Don't add rules that require dynamic analysis (HTTP traffic,
  installed APK behavior) — v2.0 is static-only.
- Don't restate generic Android best practices that R8/AGP already
  enforce.
