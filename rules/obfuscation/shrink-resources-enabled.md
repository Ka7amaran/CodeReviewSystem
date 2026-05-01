---
id: obfuscation/shrink-resources-enabled
severity: info
category: obfuscation
applies-to:
  - app/build.gradle.kts
  - app/build.gradle
since: "1.4.0"
---

# `isShrinkResources = true` у release

## Чому це важливо

`isShrinkResources` (Kotlin DSL) / `shrinkResources` (Groovy) у `release`
buildType змушує AAPT2 видаляти невикористані ресурси (`res/drawable`,
`res/string`, `res/layout`) на основі того, який код переживає
shrinking. Зазвичай зменшує розмір APK на 5-15%.

Працює тільки якщо `isMinifyEnabled = true` (бо resource-shrinker
читає shrunk-byte-code щоб зрозуміти, які ресурси ще використовуються).

## Що перевірити

1. У `app/build.gradle.kts` (або `.gradle`) у блоці
   `buildTypes { release { ... } }`.
2. Перевірити, чи присутнє:
   - Kotlin DSL: `isShrinkResources = true`
   - Groovy: `shrinkResources true`
3. Якщо ні — flag (info).
4. Якщо `isMinifyEnabled = false` — flag з reason'ом
   "isShrinkResources requires isMinifyEnabled = true".

## Як це виглядає у поганому проекті

```kotlin
release {
    isMinifyEnabled = true
    proguardFiles(...)
    // isShrinkResources відсутнє → ресурси не видаляються
}
```

## Як це має виглядати

```kotlin
release {
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(...)
}
```

## Як доповідати

```
[obfuscation/shrink-resources-enabled] INFO
  app/build.gradle.kts:<line>
  isShrinkResources не виставлено у true для release buildType — невикористані ресурси залишаться в APK.
  Як виправити: додайте `isShrinkResources = true` (Kotlin DSL) або `shrinkResources true` (Groovy) у блок `buildTypes { release { ... } }`. Потребує `isMinifyEnabled = true`.
  Див.: https://developer.android.com/studio/build/shrink-code#shrink-resources
```

## Виключення

Дозволено через `accepted-risks`, якщо проект свідомо вимагає всіх
ресурсів (наприклад, динамічно завантажує імена через
`Resources.getIdentifier(...)`).
