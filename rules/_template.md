---
id: <category>/<slug>
severity: suspicious
category: <category>
applies-to:
  - <hint-pattern>
since: "2.0.0"
requires-project-type: with-attribution
---

# <Human-readable rule title>

## Інваріант

(1-3 sentences: what behavior must hold at runtime.)

## Як перевірити

(Dataflow-trace recipe for the agent. Describe which symbols / call
chains / file types to inspect. NOT a grep recipe.)

1. (First step of reasoning.)
2. (Second step.)
3. (...)

## Як виглядає поломка

```kotlin
(minimal example of the broken behavior)
```

## Як виглядає правильно

```kotlin
(minimal example of correct behavior)
```

## Як доповідати

```
[<rule-id>] <SEVERITY-IN-CAPS>
  <file>:<line>          (or <file> if no line, or "(decentralized — see notes)" if no specific file)
  <one-sentence Ukrainian description of the violation>
  Як виправити: <one-sentence Ukrainian fix instruction>.
  Див.: <reference URL or examples/path>.
```

## Виключення

(When suppression via `accepted-deviations` is allowed. Use literal
`Жодних` if the rule cannot be silenced.)
