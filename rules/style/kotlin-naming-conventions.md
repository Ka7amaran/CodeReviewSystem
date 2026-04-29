---
id: style/kotlin-naming-conventions
severity: info
category: style
applies-to:
  - app/src/main/java/**/*.kt
since: "1.0.0"
---

# Kotlin naming conventions

## Чому це важливо

Inconsistent naming makes a multi-author codebase harder to read.
Project review explicitly checks against the Kotlin coding conventions
(camelCase functions, PascalCase classes, SCREAMING_SNAKE_CASE for
top-level `const val`, no Hungarian-notation prefixes). Issues here
are usually quick fixes; they cluster in code that was machine-
generated or copied from a different ecosystem.

## Що перевірити

1. Top-level `const val` declarations: name should be `SCREAMING_SNAKE_CASE`.
   Flag if camelCase or PascalCase.
2. Function names: `camelCase`. Flag PascalCase functions
   (except `@Composable` functions, which are PascalCase by convention).
3. Class names: `PascalCase`.
4. Object/companion-object property names that hold class references:
   `camelCase`.
5. Avoid Hungarian-notation prefixes (`mFoo`, `sBar`).

## Як це виглядає у поганому проекті

```kotlin
const val maxCount = 5                  // should be MAX_COUNT
fun ProcessOrder() = ...                // should be processOrder (not @Composable)
class user_repository                   // should be UserRepository
val mService: Service = ...             // drop the `m` prefix
```

## Як це має виглядати

```kotlin
const val MAX_COUNT = 5
fun processOrder() = ...
class UserRepository
val service: Service = ...
```

## Як доповідати

```
[style/kotlin-naming-conventions] INFO
  <file>:<line>
  <kind> "<name>" violates Kotlin naming convention (expected <expected-form>).
  Fix: rename to <suggested>.
  See: https://kotlinlang.org/docs/coding-conventions.html#naming-rules
```

## Виключення

Жодних. Конвенцію можна порушувати тільки через `@Suppress` на
конкретному оголошенні з reason — який також буде відображено у звіті
як info.
