---
id: obfuscation/proguard-rules-not-empty
severity: error
category: obfuscation
applies-to:
  - app/proguard-rules.pro
  - app/build.gradle.kts
  - app/build.gradle
since: "1.0.0"
---

# Non-empty ProGuard rules when minify is enabled

## Чому це важливо

If `isMinifyEnabled = true` in `release` build type but
`proguard-rules.pro` is empty (only the default template comments),
R8 will rename and possibly strip classes that the app accesses
reflectively (Hilt entry points, Compose runtime markers, kotlinx.
serialization annotations, JSON DTOs deserialized via reflection).
Result: silent runtime crashes in release that cannot be reproduced
in debug. This is one of the most common pre-launch outages.

## Що перевірити

1. In `app/build.gradle.kts` (or `.gradle`), find `buildTypes { release { ... } }`.
2. Detect `isMinifyEnabled = true` (Kotlin DSL) or
   `minifyEnabled true` (Groovy).
3. If minify is enabled, read `app/proguard-rules.pro`.
4. The file is considered "empty" if, after stripping `#`-comments and
   blank lines, fewer than 3 non-comment lines remain.
5. If empty + minify enabled → ERROR.

## Як це виглядає у поганому проекті

```
# Add project specific ProGuard rules here.
# (template-only comments)
```

…paired with `isMinifyEnabled = true` in gradle.

## Як це має виглядати

A non-trivial set of `-keep` rules tailored to the project's
reflective surfaces (DI, JSON, Compose markers, critical crypto
classes). See `examples/good-proguard-rules.pro`.

## Як доповідати

```
[obfuscation/proguard-rules-not-empty] ERROR
  app/proguard-rules.pro:1
  isMinifyEnabled=true but proguard-rules.pro contains only template comments (<N> non-comment lines).
  Fix: add -keep rules for at least: critical-classes from .claude/CLAUDE.md, Hilt entry points, kotlinx.serialization @Serializable classes.
  See: examples/good-proguard-rules.pro
```

## Виключення

Жодних. If you don't need keep rules, set `isMinifyEnabled = false`.
