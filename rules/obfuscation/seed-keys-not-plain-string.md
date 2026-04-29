---
id: obfuscation/seed-keys-not-plain-string
severity: warning
category: obfuscation
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "1.0.0"
---

# Crypto seeds are not plain compile-time strings

## Чому це важливо

This rule overlaps with `security/no-hardcoded-secrets` but is scoped
specifically to **the seed/key feeding your in-app obfuscation** —
because security treats it as a secrets issue, while obfuscation treats
it as an *effectiveness* issue. A plain seed string makes ALL of your
encrypted endpoints/parameters trivial to decrypt. The rule fires
even when `security/no-hardcoded-secrets` is suppressed via
`accepted-risks`, because the obfuscation-effectiveness angle is
independent.

## Що перевірити

1. Search files matching `sensitive-files` (from project's
   `.claude/CLAUDE.md`). If `.claude/CLAUDE.md` is missing or has no
   `## sensitive-files` section, fall back to all files matching this
   rule's `applies-to` patterns (`app/src/main/java/**/*.kt` and
   `**/*.java`).
2. Detect a top-level/object-level `val` or `const val` whose:
   a. name contains `seed`, `key`, `salt` (case-insensitive), AND
   b. value is a plain `String` or `ByteArray` literal of ≥16 chars.
3. Detect "junk-char" obfuscation that constructs a String from a
   `charArrayOf(...)` with hand-picked indices. Fire only when ALL of:
   a. `charArrayOf(...)` literal contains ≥8 elements.
   b. The same enclosing function/object contains a `buildString { ... }`
      OR `StringBuilder()` block where that block accesses the char
      array using NUMERIC INDEX LITERALS (e.g., `junk[1]`, `arr[12]`),
      not via iteration (`forEach`, `for`, `map`).
   c. ≥3 distinct numeric-index accesses are present.
   This pattern is reversible in seconds and provides false security.
   Without all three signals, do NOT fire (it is likely innocuous
   character processing).

## Як це виглядає у поганому проекті

```kotlin
val USER_SEED: ByteArray = "K9mT4Xq2Zp7Lw1R8Ys5Nv6Hd3Fa0BcJu".toByteArray()

private fun getTransformation(): String {
    val junk = charArrayOf('x','A','1','E','!','S',/* ... */)
    return buildString { append(junk[1]); append(junk[3]); /* ... */ }
}
```

## Як це має виглядати

Seed material loaded at runtime from outside the APK (NDK, KeyStore-
bound, server-derived after attestation). At minimum for MVP, kept in
`BuildConfig` from local `gradle.properties` so it isn't in source.

## Як доповідати

```
[obfuscation/seed-keys-not-plain-string] WARNING
  <file>:<line>
  Plain-string seed/key in compile-time constant: <name>.
  Fix: move out of source. NDK or KeyStore for production; BuildConfig from gradle.properties as a starting point.
  See: examples/good-proguard-rules.pro (commentary on "what -keep cannot save")
```

## Виключення

Дозволено через `accepted-risks`, тільки якщо seed свідомо публічний
(наприклад, public-key fingerprint, не secret). У такому разі
обґрунтування обов'язкове.
