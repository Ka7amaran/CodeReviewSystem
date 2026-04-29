# Rule file schema

Every rule lives in `rules/<category>/<rule-id-slug>.md` where `category`
is one of `style`, `security`, `obfuscation`. The filename slug must
match the `id` field after the `/`.

## Frontmatter (5 mandatory fields)

```yaml
---
id: <category>/<slug>            # e.g. security/no-cleartext-traffic
severity: error | warning | info  # error = blocks release; warning = must review; info = observation
category: style | security | obfuscation   # duplicates first id segment
applies-to:                       # glob patterns; agent skips body if no match
  - <pattern>
  - <pattern>
since: "<semver>"                 # plugin version that introduced the rule
---
```

## Body (6 mandatory sections, each `## Heading`)

1. **`## Чому це важливо`** — 2–6 sentences explaining business/security
   context. Without this section the developer does not understand why
   they're being told this. Reduces review fatigue.
2. **`## Що перевірити`** — numbered checklist for the agent. This is
   the "program" of the rule.
3. **`## Як це виглядає у поганому проекті`** — minimal failing example.
4. **`## Як це має виглядати`** — minimal correct example.
5. **`## Як доповідати`** — exact report-line template. Critical for
   consistent reports across runs.
6. **`## Виключення`** — when (if ever) the rule may be suppressed via
   `accepted-risks` in a project's `CLAUDE.md`. Use the literal text
   `Жодних` (or `None`) if the rule cannot be suppressed.

## How sub-agents apply rules (reference)

1. Read the frontmatter of every file in `rules/<own-category>/`.
2. Filter by `applies-to`: skip rules whose patterns don't match any
   project file.
3. For survivors, read the body.
4. Read `accepted-risks` from `.claude/CLAUDE.md` of the project; for
   each suppressed rule, check whether its `## Виключення` allows it.
5. Apply `## Що перевірити` to the project, formulate findings using
   `## Як доповідати`.
6. Group findings by severity in the final markdown report.
