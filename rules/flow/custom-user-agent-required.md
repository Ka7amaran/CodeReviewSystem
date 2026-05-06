---
id: flow/custom-user-agent-required
severity: critical
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.1.0"
requires-project-type: with-attribution
---

# Кастомний User-Agent у HTTP-клієнтах (обов'язково)

## Інваріант

Кожен HTTP-клієнт у проєкті, який викликає бекенд (зокрема POST на
`backend-domain` з attribution-payload'ом), має мати **явно виставлений
User-Agent**. Дефолтний UA від Ktor (`Ktor client`) або OkHttp
(`okhttp/X.Y.Z`) — критичний баг.

Стандартний підхід команди:
```
System.getProperty("http.agent") ?: "Android"
```

Це виставляється на рівні клієнта (Ktor `install(UserAgent)`) або через
interceptor (OkHttp). Альтернативно — кастомний рядок, що містить
applicationId і versionName, але **не SDK-default**.

## Чому критично

Бекенд-системи attribution часто фільтрують запити з очевидним SDK-
фінгерпринтом (`okhttp/4.x.x`, `Ktor client`) як "не реальний
користувач" — це антифрод-логіка. Сервер може повертати помилку,
ігнорувати запит, або класифікувати як bot-traffic, що ламає метрики.
Команда фіксувала це як проблему на минулих проектах.

## Як перевірити

1. Знайти кожен HTTP-клієнт у `applies-to` файлах:
   - **Ktor**: `HttpClient(...)`, `HttpClient { ... }`, `install(UserAgent)`.
   - **OkHttp**: `OkHttpClient.Builder()`, `addInterceptor`, header
     `"User-Agent"`.
   - **Retrofit**: під ним лежить OkHttp — перевіряти OkHttpClient.
   - **HttpURLConnection**: `setRequestProperty("User-Agent", ...)`.
2. Для кожного клієнта перевірити, чи виставлений UA ЯВНО:
   - Ktor: блок `install(UserAgent) { agent = "..." }` присутній.
   - OkHttp: interceptor що ставить `addHeader("User-Agent", ...)`
     присутній.
   - HttpURLConnection: явний `setRequestProperty("User-Agent", ...)`.
3. Якщо UA явно НЕ виставлений — finding `critical`.
4. Якщо UA виставлений, але значення містить літерально `okhttp` /
   `Ktor` / тільки `Android` без додаткової інформації — finding
   `critical` (це фактично default-equivalent).

Це **dataflow-перевірка**: агент має знайти точку instantiation
кожного клієнта і простежити чи UA-конфігурація присутня в межах того
ж класу/функції/builder'а.

## Як виглядає поломка

```kotlin
// Ktor — UA не виставлений → "Ktor client/<version>"
val client = HttpClient(Android) {
    install(ContentNegotiation) { json() }
}

// OkHttp — без custom interceptor'а → "okhttp/4.12.0"
val client = OkHttpClient.Builder().build()
```

## Як виглядає правильно

```kotlin
// Ktor
val client = HttpClient(Android) {
    install(UserAgent) {
        agent = System.getProperty("http.agent") ?: "Android"
    }
    install(ContentNegotiation) { json() }
}

// OkHttp
val client = OkHttpClient.Builder()
    .addInterceptor { chain ->
        val ua = System.getProperty("http.agent") ?: "Android"
        val request = chain.request().newBuilder()
            .header("User-Agent", ua)
            .build()
        chain.proceed(request)
    }
    .build()
```

## Як доповідати

```
[flow/custom-user-agent-required] CRITICAL
  <file>:<line>   (точка створення HTTP-клієнта)
  HTTP-клієнт <Ktor|OkHttp|HttpURLConnection> не виставляє кастомний User-Agent — використовується дефолтний SDK-фінгерпринт. Бекенд може фільтрувати запит як bot-traffic.
  Як виправити: додайте `install(UserAgent) { agent = System.getProperty("http.agent") ?: "Android" }` (Ktor) або interceptor з User-Agent header (OkHttp). Команда вимагає це обов'язково для всіх клієнтів.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.6
```

## Виключення

Жодних. UA-policy команди фіксована — кастомний UA обов'язковий для
всіх HTTP-клієнтів у production-збірці. Не вимикається через
`accepted-deviations`.
