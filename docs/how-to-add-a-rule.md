# How to add a rule

## TL;DR

1. `cp rules/_template.md rules/<category>/<your-slug>.md`
2. Fill the 5 frontmatter fields.
3. Fill the 6 body sections (Чому → Що перевірити → Поганий приклад →
   Хороший приклад → Як доповідати → Виключення).
4. Bump plugin minor version in `.claude-plugin/plugin.json` and add a
   line to `CHANGELOG.md`.
5. PR. Smoke-test against `Juice-Master-Factory` and `Joker-Speed-Seven`
   per `docs/smoke-test.md` before merge.

## Choosing the right severity

- **error** — blocks release. Use only if the rule corresponds to a
  hard requirement (Play policy, certain crash, leaked secret).
- **warning** — must review and either fix or accept. Default for
  best-practices.
- **info** — observation; doesn't change verdict. Use for style nits
  or "consider doing X".

## `applies-to` patterns

- Use globs relative to the project root (e.g., `app/src/main/**/*.kt`).
- Be **narrow**. The agent uses this for pre-filtering — wide patterns
  cost tokens and slow the run.
- For manifest rules, target `app/src/main/AndroidManifest.xml`
  exactly.

## When to use "Жодних" in `## Виключення`

Use literal `Жодних` (or `None`) when the rule:
- corresponds to a Google Play hard requirement, OR
- corresponds to a certain runtime crash, OR
- there is a built-in legitimate workaround at the source level
  (e.g., scoped `network_security_config.xml`).

Otherwise, document a narrow exception path.

## Anti-patterns when writing rules

- Don't write rules that overlap silently with another rule. If a
  finding could trigger two rules, pick one as the canonical.
- Don't let `## Що перевірити` reference project specifics. The rule
  must work across all your apps.
- Don't bury the fix in prose. The fix must appear in the
  `## Як доповідати` template explicitly.
- Don't add rules that require dynamic analysis (e.g., "the app makes
  fewer than N HTTP requests during cold start"). MVP is static-only.
