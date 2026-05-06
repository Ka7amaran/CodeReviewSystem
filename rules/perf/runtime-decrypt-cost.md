---
id: perf/runtime-decrypt-cost
severity: observation
category: perf
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.1.0"
---

# Вартість runtime-decrypt операцій

## Інваріант

Якщо проєкт використовує runtime-decrypt для приховування
endpoint-URL'ів або інших обфускованих рядків (типовий паттерн команди
з §3.10), кожен виклик `.dec(...)` коштує:
- AES init: 5-50ms (залежно від пристрою).
- Char-array shuffle / Base64 decode: 1-10ms.
- Garbage allocation: ~30 KB на виклик.

Якщо decrypt викликається багато разів (наприклад, кожен POST
recompute'ить URL з нуля), на холодному старті це додає 200-500ms,
на гарячому шляху — burst CPU.

Це **observation**-правило: ніколи не блокує реліз. Дає developer'у
карту "де decrypt викликається повторно і де його варто кешувати".

## Як перевірити

1. Знайти усі виклики decrypt-функції (з §3.10 dataflow trace —
   функція що повертає String після `Cipher.doFinal(...)` або
   еквіваленту).
2. Для кожного виклику перевірити:
   - **Чи кешується результат?** Тобто чи перший виклик зберігає в
     `lateinit var` / `by lazy` / `Map<key, decrypted>` для повторного
     використання, чи кожен виклик заново декриптує.
   - **Скільки разів decrypt викликається на стартовому шляху?**
     Якщо більше 3 — observation.
   - **Чи decrypt відбувається на main thread?** Якщо так — це
     дублює finding `perf/startup-blocking`, але з конкретним
     контекстом decrypt-cost.
   - **Чи decrypt результат може бути обчислений compile-time через
     BuildConfig?** (Якщо seed і encrypted blob обидва статичні —
     можна decrypt у Gradle build script і покласти в BuildConfig.)

Кожна знайдена неоптимальність — окремий observation.

## Як виглядає поломка

```kotlin
class BackendApi {
    suspend fun postAttribution(uuid: String, ref: String, adId: String) {
        val url = SecretsHelper.dec(URL_PARTS)         // ❌ decrypt кожного виклику
        httpClient.post(url) { ... }
    }

    suspend fun postEvent(name: String) {
        val url = SecretsHelper.dec(URL_PARTS)         // ❌ decrypt знову
        httpClient.post("$url/event/$name") { ... }
    }
}
```

## Як виглядає правильно

```kotlin
class BackendApi {
    private val baseUrl: String by lazy {
        SecretsHelper.dec(URL_PARTS)                    // ✅ один раз, lazy
    }

    suspend fun postAttribution(uuid: String, ref: String, adId: String) {
        httpClient.post(baseUrl) { ... }
    }

    suspend fun postEvent(name: String) {
        httpClient.post("$baseUrl/event/$name") { ... }
    }
}
```

Або, якщо seed і encrypted blob обидва статичні:

```kotlin
// gradle/build-script — decrypt у Gradle, не на пристрої
buildConfigField("String", "BACKEND_URL", "\"https://realdomain.store\"")

// runtime — нуль cost
val baseUrl = BuildConfig.BACKEND_URL
```

(Останній варіант — компроміс із обфускацією. Якщо обфускація URL
важлива саме у release APK — використовувати `by lazy` варіант.)

## Як доповідати

```
[perf/runtime-decrypt-cost] OBSERVATION
  <file>:<line>
  Decrypt-функція `<name>` викликається <N> разів на стартовому шляху без кешування. Estimated cost: ~<N×AES_init>ms на cold-start.
  Як виправити: загорніть результат у `by lazy { ... }` або `lateinit var` поле, ініціалізоване один раз у `Application.onCreate`.
  Див.: https://developer.android.com/topic/performance/vitals/launch-time
```

## Виключення

Дозволено через `accepted-deviations`, якщо decrypt свідомо викликається
кожного разу (наприклад, ключ ротується між викликами і кешування
ламає security-логіку). Обґрунтування обов'язкове.
