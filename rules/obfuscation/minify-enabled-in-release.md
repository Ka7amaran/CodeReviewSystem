---
id: obfuscation/minify-enabled-in-release
severity: warning
category: obfuscation
applies-to:
  - app/build.gradle.kts
  - app/build.gradle
since: "1.4.0"
---

# `isMinifyEnabled = true` у release-buildType

## Чому це важливо

`isMinifyEnabled` (Kotlin DSL) / `minifyEnabled` (Groovy) у `release`
buildType вмикає R8:
1. **Shrinking** — видаляє невикористаний код.
2. **Obfuscation** — перейменовує класи/методи на короткі імена.
3. **Optimization** — інлайнить виклики, видаляє dead branches.

Без minify release-APK:
- Більший на 30-60% (видний код, дебаг-інформація).
- Легко декомпілюється з оригінальними іменами класів і методів.
- Видає логіку реверс-енжинірам за хвилини.

Це базове посилання захисту IP від конкурентів і захисту від
автоматизованого зловмисного аналізу. Для гри з обфускованою logic
у `core/decrypt`, `settings/crypto` тощо — обов'язкове.

## Що перевірити

1. У `app/build.gradle.kts` (або `.gradle`) знайти блок
   `buildTypes { release { ... } }`.
2. Перевірити наявність:
   - Kotlin DSL: `isMinifyEnabled = true`
   - Groovy: `minifyEnabled true`
3. Якщо `false` або відсутнє — flag.

## Як це виглядає у поганому проекті

```kotlin
android {
    buildTypes {
        release {
            // isMinifyEnabled не виставлено = за замовчуванням false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }
}
```

## Як це має виглядати

```kotlin
android {
    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

## Як доповідати

```
[obfuscation/minify-enabled-in-release] WARNING
  app/build.gradle.kts:<line>
  isMinifyEnabled не встановлено у true для release buildType — R8 не запускається на фінальному APK.
  Як виправити: додайте `isMinifyEnabled = true` (Kotlin DSL) або `minifyEnabled true` (Groovy) у блок `buildTypes { release { ... } }`.
  Див.: https://developer.android.com/studio/build/shrink-code
```

## Виключення

Дозволено через `accepted-risks` тільки для проектів, де release-APK
свідомо не обфускується (наприклад, internal QA-build). Обґрунтування
обов'язкове.
