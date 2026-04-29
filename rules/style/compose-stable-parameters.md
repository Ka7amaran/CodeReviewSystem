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
3. Compose skipping is all-or-nothing: a single unstable parameter makes
   the Composable unskippable. To balance this against false-positive
   noise:
   a. ALWAYS flag any unstable collection parameter (`List`, `Map`,
      `Set`) — these are common and the fix (`ImmutableList`/`@Immutable`
      wrapper) is well-known.
   b. ALWAYS flag composables with 2+ unstable non-primitive parameters.
   c. For composables with EXACTLY ONE unstable non-collection
      parameter: emit an `info`-level reminder (using the same finding
      template but with severity INFO in the output line) noting the
      Composable is unskippable; do NOT emit it as a `warning`. Single-
      parameter cases are common in legitimate APIs and the developer
      may have weighed the tradeoff.
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
// Option 1 (preferred — no new dependency): wrap the collection in a
// stable holder.
@Immutable
data class Scores(val items: List<Score>)

@Composable
fun ScoreList(
    scores: Scores,
    onClick: (Score) -> Unit
) { ... }

// Caller — also hoist the lambda:
val onClick = remember(viewModel) { { s: Score -> viewModel.select(s) } }
ScoreList(viewModel.scoresImmutable, onClick)

// Option 2 (requires `kotlinx.collections.immutable`): use ImmutableList.
@Composable
fun ScoreList(
    scores: ImmutableList<Score>,
    onClick: (Score) -> Unit
) { ... }
```

## Як доповідати

```
[style/compose-stable-parameters] WARNING
  <file>:<line>
  @Composable "<name>" takes unstable parameter <param>: <type>.
  Fix (in order of preference, no dep added first): annotate the parameter type with `@Immutable` or wrap in a stable holder class; OR hoist function-reference parameters via `remember`; OR migrate the collection to `ImmutableList`/`PersistentList` (requires adding the `kotlinx.collections.immutable` dependency).
  See: https://developer.android.com/jetpack/compose/performance/stability
```

## Виключення

Дозволено через `accepted-risks` для рідкісних композаблів, що
свідомо інвалідуються щотакта (наприклад, FPS-метр).

## Convention

This rule's frontmatter severity is `warning`, but the auditor MAY emit
findings at `info` severity for the specific case of a single non-
collection unstable parameter (see "Що перевірити" step 3.c). In all
other cases, severity is `warning`. The output report groups by EMITTED
severity, not frontmatter severity.
