---
id: obfuscation/crypto-classes-keep-rules-present
severity: error
category: obfuscation
applies-to:
  - app/proguard-rules.pro
since: "1.0.0"
---

# Critical crypto classes are covered by `-keep` rules

## Чому це важливо

When `isMinifyEnabled = true`, R8 may rename classes/methods used
reflectively by your decryption layer (e.g., Cipher transformation
strings built at runtime, helper objects accessed via simpleName, or
classes loaded by `Class.forName`). Renaming silently breaks decryption,
the app can't bootstrap (splash hangs, endpoint never resolves), and the
crash is hard to reproduce locally without a release build.

## Що перевірити

1. Take the `critical-classes` list from `.claude/CLAUDE.md` (already
   resolved by the obfuscation-auditor's procedure — either declared or
   auto-detected).
2. For each entry (a glob like `com.example.app.crypto.**`), check
   that `app/proguard-rules.pro` contains at least one `-keep` (or
   `-keep class`, `-keepclassmembers`, `-keepclasseswithmembers`)
   rule whose pattern covers it.
3. The pattern must use `**` (deep wildcard) for `**` globs, or `*`
   for shallow ones, matching the glob's intent.

## Як це виглядає у поганому проекті

```
# proguard-rules.pro
-dontwarn com.fancy.lib.**
# (no -keep for crypto classes despite critical-classes declaring them)
```

## Як це має виглядати

For `critical-classes` containing `com.example.app.core.crypto.**`:

```
# Keep crypto layer (R8 must not rename — runtime reflection on class names)
-keep class com.example.app.core.crypto.** { *; }
```

## Як доповідати

```
[obfuscation/crypto-classes-keep-rules-present] ERROR
  app/proguard-rules.pro
  No -keep rule covers critical-classes pattern: <pattern>
  Fix: add `-keep class <pattern> { *; }` (and consider `-keepclassmembers` if you only need members).
  See: examples/good-proguard-rules.pro
```

## Виключення

Жодних. If a class is in `critical-classes`, it must be kept.
