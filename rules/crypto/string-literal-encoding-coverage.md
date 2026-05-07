---
id: crypto/string-literal-encoding-coverage
severity: critical
category: crypto
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
  - gradle/libs.versions.toml
  - app/build.gradle.kts
since: "2.5.0"
---

# Покриття обфускацією усіх рядкових літералів у production-коді

## Інваріант

Якщо проєкт використовує string-obfuscation механізм (lspanoid через
`@LSParanoid`, paranoid через `@Obfuscate`, stringfog, runtime
`.dec(...)` з AES/XOR-декодуванням, або еквівалент), цей механізм
має бути застосований **до КОЖНОГО** файлу з нетривіальними
рядковими літералами під `app/src/main/java/**/`. Часткове покриття
— критичний баг: незахищені рядки видно у decompiled APK звичайним
`apktool d`, що ламає security model команди (приховування endpoint
URL, API keys, OAuth client IDs, шляхів до encrypted assets тощо).

Контракт: **"якщо ти декларуєш що обфускуєш — зроби це усюди".**
Якщо проєкт обфускацію не використовує — правило skip'ається
(немає expectation, немає контракту).

## Як перевірити

### Крок 1 — Stage 0 detection: чи проєкт обфускує рядки?

Шукати **будь-який** з трьох сигналів:

- **Залежність:** у `gradle/libs.versions.toml` або
  `app/build.gradle.kts` присутня бібліотека `lspanoid`, `paranoid`,
  `stringfog`, `string-encrypt`, `dexguard`, або еквівалент
  string-obfuscation tool'у.
- **Annotation у коді:** хоча б один файл має `@LSParanoid`,
  `@Obfuscate`, `@StringEncrypt`, `@Encrypt`, `@ObfuscateLiterals`.
- **Runtime-decrypt pattern:** хоча б один виклик `.dec(...)`,
  `decode(...)` що повертає String, AES/XOR-decrypt функція що
  виробляє String для подальшого використання як URL/key/secret.

Якщо **жодного** сигналу не знайдено → правило skip'ається з
причиною "проєкт не декларує string-obfuscation; немає контракту
для перевірки покриття". Жодних findings.

### Крок 2 — Перевірка покриття (тільки якщо Крок 1 виявив сигнал)

Для кожного `.kt` / `.java` файлу під `app/src/main/java/**/`:

1. Прочитати файл.
2. Знайти всі рядкові літерали довжиною **>= 5 символів**.
3. Виключити whitelist (НЕ враховувати у перевірці):
   - **Log-tag literals**: literal, що передається першим аргументом
     у `Log.d/v/i/w/e(...)` чи присвоюється `private const val TAG`.
   - **Annotation arguments**: literal всередині `@SerialName("...")`,
     `@Json(name = "...")`, `@SerializedName("...")`,
     `@Inject @Named("...")`, `@Retention`, `@Target`, тощо.
   - **HTTP-method / MIME constants**: `"GET"`, `"POST"`, `"PUT"`,
     `"DELETE"`, `"PATCH"`, `"OPTIONS"`, `"application/json"`,
     `"text/plain"`, `"multipart/form-data"`.
   - **Empty / whitespace-only**: `""`, `" "`, `"\n"`.
   - **Format placeholders**: literal що містить виключно
     `%s`/`%d`/`%f`/`{0}`/`{1}` без іншого контенту.
   - **Sealed class / enum / data class field defaults**: рядки що
     є default-значеннями polymorphism-discriminator полів.
   - **Test-only code**: будь-що під `app/src/test/`,
     `app/src/androidTest/`, або у файлах з `@RunWith` annotation.
   - **R.string references**: `R.string.foo` (це не string literal,
     це ID).
4. Для решти string literals (значущих):
   - Перевірити, чи файл / клас / функція має class-level або
     file-level `@LSParanoid` / `@Obfuscate` / `@StringEncrypt` /
     еквівалент. Файл-level annotation покриває весь файл.
   - АБО чи кожен такий literal використовується ВИКЛЮЧНО як аргумент
     `.dec(...)` / runtime-decrypt функції (тобто це закодований
     blob, не plaintext).
   - АБО чи literal винесений у `BuildConfig` (декрипт відбувається
     compile-time у Gradle build script).
5. Якщо у файлі є хоча б один значущий string literal, на який
   **не** поширюється жоден з трьох механізмів захисту → finding
   `critical` для цього файлу.

### Крок 3 — Один finding на файл

Per-file gранулярність: розробник бачить точний файл і кількість
проблемних literal'ів. Не aggregate, не per-line — це робить fix
конкретним і відстежним.

## Як виглядає поломка

```kotlin
// app/src/main/java/com/example/api/BackendUrls.kt
// ❌ файл НЕ має @LSParanoid, literals НЕ проходять через .dec(...)
object BackendUrls {
    const val PROD_BASE = "https://api.realdomain.store"        // ❌ plaintext
    const val ATTRIBUTION = "/v1/attribution"                    // ❌ plaintext
    const val ONESIGNAL_APP_ID = "abc-123-def-456"               // ❌ plaintext
}
```

```kotlin
// app/src/main/java/com/example/data/Helper.kt
// ❌ Частина файлу обфускована, частина — ні
@LSParanoid
class EncryptedHelper {
    fun secret() = "my-secret-key-1234"                          // ✅ покрито annotation
}

class PlainHelper {                                              // ❌ без annotation
    fun secret() = "another-leaked-secret"                       // ❌ plaintext
}
```

## Як виглядає правильно

```kotlin
// Варіант А — file-level annotation покриває весь файл
@file:LSParanoid
package com.example.api

object BackendUrls {
    const val PROD_BASE = "https://api.realdomain.store"        // ✅ обфусковано compile-time
    const val ATTRIBUTION = "/v1/attribution"                    // ✅
    const val ONESIGNAL_APP_ID = "abc-123-def-456"               // ✅
}
```

```kotlin
// Варіант Б — runtime decrypt pattern
object BackendUrls {
    val PROD_BASE: String by lazy {
        SecretsHelper.dec(byteArrayOf(0x4f, 0x2a, /* ... */))    // ✅ encrypted blob
    }
}
```

```kotlin
// Варіант В — BuildConfig (compile-time через Gradle)
// build.gradle.kts:
//   buildConfigField("String", "BACKEND_URL", "\"<encrypted-string>\"")
val baseUrl = BuildConfig.BACKEND_URL                            // ✅
```

## Як доповідати

```
[crypto/string-literal-encoding-coverage] CRITICAL
  <file>:<line>   (перший проблемний рядок у файлі)
  Файл містить <N> значущих рядкових літералів, що НЕ покриті обфускацією: <короткий список перших 3-5 у форматі "line X: short preview…">. Файл НЕ має `@LSParanoid` / `@Obfuscate` / еквівалентної annotation, і literals не проходять через runtime-decrypt. У decompiled APK ці рядки видно у plaintext.
  Як виправити: додайте `@file:LSParanoid` (або еквівалент команди) на початок файлу, АБО винесіть literals у BuildConfig, АБО заведіть їх через runtime-decrypt blob. Один з трьох — на ваш розсуд.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.10
```

## Виключення

Дозволено через `accepted-deviations` для конкретного файлу, якщо
команда свідомо лишила його plaintext (наприклад, debug-only helper,
що буде вирізаний R8 у release-збірці; resource-name registry
що ніколи не містить secrets). Формат:

```
crypto/string-literal-encoding-coverage:com/example/debug/DebugLogger.kt: debug-only helper, R8-stripped у release
```

Обґрунтування обов'язкове, із зазначенням чому plaintext acceptable
для цього файлу.
