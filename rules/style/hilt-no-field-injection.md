---
id: style/hilt-no-field-injection
severity: warning
category: style
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "1.0.0"
---

# Prefer constructor injection over `@Inject` on fields

## Чому це важливо

Hilt supports both `@Inject` constructor parameters and `@Inject` on
mutable fields, but the latter forces the dependency to be `lateinit
var` (or `var = null`) — both are mutable, both invite NPEs on early
access (e.g., before `onCreate`), and both make tests harder (you
have to manually populate fields). Constructor injection produces
final fields, fails at construction time if a binding is missing, and
is naturally testable.

## Що перевірити

1. For each class annotated `@HiltAndroidApp`, `@AndroidEntryPoint`,
   `@HiltViewModel`, find every field with `@Inject`.
2. If the field type is something Hilt could inject via constructor
   (any `@Inject`-able), flag it. (Activities/Fragments/services are
   exempt because Android instantiates them — they must use field
   injection. Flag only ViewModels and plain classes.)

## Як це виглядає у поганому проекті

```kotlin
@HiltViewModel
class MyViewModel : ViewModel() {
    @Inject lateinit var repo: Repository
    @Inject lateinit var clock: Clock
}
```

## Як це має виглядати

```kotlin
@HiltViewModel
class MyViewModel @Inject constructor(
    private val repo: Repository,
    private val clock: Clock,
) : ViewModel()
```

## Як доповідати

```
[style/hilt-no-field-injection] WARNING
  <file>:<line>
  @Inject on field "<name>" in <class> (a Hilt component that supports constructor injection).
  Fix: move to constructor parameters. Activities/Fragments/Services may keep field injection.
  See: https://dagger.dev/hilt/quick-start
```

## Виключення

Дозволено для класів, що ініціалізуються Android-системою
(Activity/Fragment/Service/BroadcastReceiver/ContentProvider/Application).
