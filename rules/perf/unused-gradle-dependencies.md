---
id: perf/unused-gradle-dependencies
severity: observation
category: perf
applies-to:
  - app/build.gradle.kts
  - app/build.gradle
  - gradle/libs.versions.toml
since: "2.10.0"
---

# Невикористані Gradle-залежності

## Інваріант

Кожна задекларована в `app/build.gradle(.kts)` (або підключена через
`gradle/libs.versions.toml`) залежність має мати **хоча б один
`import`** у коді проєкту (`app/src/main/{java,kotlin}/`) — або
очевидну причину бути там без імпорту (annotation processor,
gradle-плагін, ресурси, тема).

Невикористані залежності збільшують розмір APK, час build-у, кількість
методів у dex, а часом тягнуть зайві permissions та ProGuard noise.

Це **observation**-правило: ніколи не блокує реліз. Просто звертає
увагу на dead weight у блоці `dependencies { ... }`.

## Як перевірити

1. Зчитати список залежностей з:
   - `app/build.gradle.kts` / `app/build.gradle` — рядки виду
     `implementation("group:artifact:version")`,
     `api("group:artifact:version")`,
     `implementation(libs.something)` (резолвити через
     `gradle/libs.versions.toml [libraries]`).
   - `gradle/libs.versions.toml` `[libraries]` — `module = "group:artifact"`
     або `group = "...", name = "..."`.
2. Для кожної залежності визначити **типовий import-root** (один-два
   рядки):
   - `com.squareup.okhttp3:okhttp` → `okhttp3.`
   - `com.squareup.retrofit2:retrofit` → `retrofit2.`
   - `io.reactivex.rxjava3:rxjava` → `io.reactivex.rxjava3.`
   - `androidx.compose.material3:material3` → `androidx.compose.material3.`
   - `com.google.firebase:firebase-analytics` → `com.google.firebase.analytics.`
   - `com.onesignal:OneSignal` → `com.onesignal.`
   - `com.android.installreferrer:installreferrer` → `com.android.installreferrer.`
   - Загальне правило: `group:artifact` → `group.<artifact-tail>.`;
     зважайте на суфікси `-ktx`, `-android`, `-core`, `-runtime` —
     вони зазвичай не потрапляють у package name.
3. Grep `import <root>` (case-sensitive) у
   `app/src/main/{java,kotlin}/**/*.{kt,java}`. Хоча б одне
   співпадіння → залежність використана.
4. **Список винятків** (не репортити):
   - **Build-time plugins**: усі `id("...")` у `plugins { }`,
     `gradle-plugin` у coordinates, `kotlin-android`, `kotlin-kapt`,
     `kotlin-parcelize`, `kotlin-serialization`, `hilt.android.plugin`,
     `dagger.hilt.android.gradle.plugin`.
   - **Annotation processors / KSP**: усі залежності, оголошені
     через `kapt(...)` / `ksp(...)` блоки — вони генерують код без
     явного import у source.
   - **Theme / resource only**:
     - `androidx.appcompat:appcompat` (підключається через
       `<style parent="Theme.AppCompat...">`).
     - `com.google.android.material:material` (через
       `Theme.MaterialComponents`).
     - `androidx.constraintlayout:constraintlayout` — підтвердити
       через grep у `app/src/main/res/layout/**/*.xml` на
       `androidx.constraintlayout`.
   - **Test-only**: усі залежності з configuration prefix
     `testImplementation`, `androidTestImplementation`, `debug*`,
     `kaptTest`, `kspTest`. Це правило стосується main code.
5. Для кожної залежності, що залишилася без import-у і не у списку
   винятків → emit OBSERVATION з coordinates і recommendation.

## Як виглядає поломка

```kotlin
// app/build.gradle.kts
dependencies {
    implementation("com.squareup.okhttp3:okhttp:4.12.0")           // ❌ ніде не імпортується
    implementation("io.reactivex.rxjava3:rxjava:3.1.8")            // ❌ legacy, переїхали на Flow
    implementation("com.jakewharton.timber:timber:5.0.1")          // ❌ замінили на Log напряму
    implementation("androidx.appcompat:appcompat:1.6.1")           // ✅ theme через Theme.AppCompat
    implementation("com.google.firebase:firebase-analytics:21.5.0") // ✅ Firebase.analytics() у коді
}
```

## Як виглядає правильно

```kotlin
// app/build.gradle.kts
dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")           // ✅ theme
    implementation("com.google.firebase:firebase-analytics:21.5.0") // ✅ used
    // OkHttp / RxJava / Timber видалені — не використовуються
}
```

## Як доповідати

**OBSERVATION** (одна залежність без import-у):
```
[perf/unused-gradle-dependencies] OBSERVATION
  app/build.gradle.kts:<line>    (або gradle/libs.versions.toml:<line>)
  Залежність `<group:artifact:version>` задекларована, але `import <package-root>` не знайдено в `app/src/main/{java,kotlin}/`. Потенційно невикористана — збільшує розмір APK і час build-у без користі.
  Як виправити: перевірте чи реально потрібна (можливо через ksp/kapt/plugin без явного import); якщо ні — видаліть рядок з gradle. Якщо так — додайте `perf/unused-gradle-dependencies: <group:artifact> — <reason>` у `accepted-deviations`.
  Див.: https://developer.android.com/build/dependencies
```

## Виключення

Дозволено через `accepted-deviations` для конкретної залежності, якщо
вона використовується через механізм поза статичним import-grep:
annotation processor у незвичному блоці, runtime classloading,
build-script reflection, чи плагін, що не потрапив у список винятків.
Формат:
`perf/unused-gradle-dependencies: com.squareup.okhttp3:okhttp — used through KSP processor`.
Обґрунтування обов'язкове.
