---
id: style/compose-stable-parameters
severity: warning
category: style
applies-to:
  - app/src/main/java/**/*.kt
since: "1.0.0"
---

# Composable parameters should be stable to enable skipping

## Чому це важливо

Jetpack Compose skips a Composable on recomposition only if all of its
parameters are "stable" (primitive, `@Stable`, `@Immutable`, or
provably unchanged). When a Composable receives a `MutableList`,
`MutableState` (instead of its value), or a function reference created
inline, Compose recomposes it on every parent invalidation. In a
gameplay loop or a list with hundreds of items this measurably tanks
frame rate.

## Що перевірити

1. Find every function annotated `@Composable`.
2. For each non-primitive parameter, check whether its declared type
   is a known stable type (List<X> → unstable; ImmutableList → stable;
   data class → stable iff all properties stable; classes annotated
   `@Stable` or `@Immutable` → stable).
3. Flag composables that take 2+ unstable parameters or any unstable
   collection parameter (`List`, `Map`, `Set`).
4. For lambdas: flag `() -> Unit` parameters used inside `LazyColumn`
   `items {}` blocks where the lambda is created inline at the call
   site (causes recomposition every parent recomposition).

## Як це виглядає у поганому проекті

```kotlin
@Composable
fun ScoreList(scores: List<Score>, onClick: (Score) -> Unit) {
    LazyColumn { items(scores) { Row(it, onClick) } }
}

// caller:
ScoreList(viewModel.scores, onClick = { viewModel.select(it) })   // lambda recreated each recomposition
```

## Як це має виглядати

```kotlin
@Composable
fun ScoreList(
    scores: ImmutableList<Score>,
    onClick: (Score) -> Unit
) { ... }

// caller — hoist the lambda:
val onClick = remember(viewModel) { { score: Score -> viewModel.select(score) } }
ScoreList(viewModel.scoresImmutable, onClick)
```

## Як доповідати

```
[style/compose-stable-parameters] WARNING
  <file>:<line>
  @Composable "<name>" takes unstable parameter <param>: <type>.
  Fix: change to ImmutableList/PersistentList, or annotate the type @Immutable, or hoist the function reference via remember.
  See: https://developer.android.com/jetpack/compose/performance/stability
```

## Виключення

Дозволено через `accepted-risks` для рідкісних композаблів, що
свідомо інвалідуються щотакта (наприклад, FPS-метр).
