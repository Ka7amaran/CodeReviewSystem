---
id: security/custom-user-agent-not-default
severity: warning
category: security
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "1.5.0"
---

# Кастомний User-Agent у HTTP-клієнтах (не дефолтний)

## Чому це важливо

Дефолтний User-Agent у Ktor (`Ktor client`) або OkHttp (`okhttp/4.12.0`)
— червоний прапор для серверів anti-fraud та anti-bot:
1. Сервери attribution-провайдерів (наш бекенд, partners) часто
   фільтрують запити з очевидним SDK-фінгерпринтом як "не реального
   користувача".
2. Play Store-інтеграції (Install Referrer, attribution-сервіси)
   використовують User-Agent для розрізнення organic vs scripted
   traffic.
3. У логах сервера купа `okhttp/X.Y.Z` робить аналіз неможливим — не
   видно з якого з 5 наших додатків прийшов запит.

Стандарт команди: User-Agent = системний string (`http.agent`
property), який Android заповнює як `Mozilla/5.0 (Linux; Android X;
ModelY) AppleWebKit/...`. Якщо `http.agent` не доступний — fallback
на `"Android"` або custom-string з applicationId і versionName.

## Що перевірити

1. Знайти HTTP-клієнти у файлах `applies-to`:
   - Ktor: `HttpClient(...)`, `HttpClient { ... }`, `install(UserAgent)`.
   - OkHttp: `OkHttpClient.Builder()`, `addInterceptor`, header
     `"User-Agent"`.
   - HttpURLConnection: `setRequestProperty("User-Agent", ...)`.
2. Для кожного клієнта перевірити, чи виставлений User-Agent
   ЯВНО (не залишений на default). Тригери:
   - Ktor: `install(UserAgent) { agent = "..." }` присутній.
   - OkHttp: interceptor що ставить `addHeader("User-Agent", ...)`
     присутній.
3. Якщо явного set'у немає — flag.
4. Якщо set є, але значення містить літерально "okhttp" або "Ktor" або
   "Android" без додаткової інформації — теж flag (це ще defaults).

## Як це виглядає у поганому проекті

```kotlin
// Ktor — User-Agent не виставлений = "Ktor client"
val client = HttpClient(Android) {
    install(ContentNegotiation) {
        json()
    }
}

// OkHttp — без custom interceptor'а = "okhttp/4.12.0"
val client = OkHttpClient.Builder()
    .build()
```

## Як це має виглядати

```kotlin
// Ktor
val client = HttpClient(Android) {
    install(UserAgent) {
        agent = System.getProperty("http.agent") ?: "Android"
    }
    install(ContentNegotiation) {
        json()
    }
}

// або OkHttp
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
[security/custom-user-agent-not-default] WARNING
  <file>:<line>
  HTTP-клієнт <Ktor|OkHttp|HttpURLConnection> не виставляє кастомний User-Agent — використовується дефолтний SDK-фінгерпринт.
  Як виправити: додайте `install(UserAgent) { agent = System.getProperty("http.agent") ?: "Android" }` (Ktor) або interceptor з `User-Agent` header (OkHttp). Сервер attribution-flow покладається на реалістичний UA.
  Див.: https://developer.android.com/reference/java/lang/System#getProperty(java.lang.String)
```

## Виключення

Дозволено через `accepted-risks` для internal-debug HTTP-клієнтів, що
ходять на dev-сервер без attribution. Обґрунтування обов'язкове.
