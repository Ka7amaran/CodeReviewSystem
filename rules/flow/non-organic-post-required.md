---
id: flow/non-organic-post-required
severity: suspicious
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
requires-project-type: with-attribution
---

# Non-organic користувачі відправляють POST на бекенд

## Інваріант

Для non-organic користувачів (referrer не містить
`utm_medium=organic`) має виконатись HTTP POST на бекенд із тілом
`{uuid, ref, adId}` (точні ключі узгоджуються з бекендом — важлива
наявність трьох значень).

URL endpoint **визначається з коду** (Stage 0 валідатора). Він
може бути літеральним (`"https://x.store/track"`), або зашифрованим
at rest (`.dec(...)` / XOR-Base64 / AES — типовий team-pattern).
Зашифрований URL — НЕ привід для finding'а; це очікуваний патерн.

(User-Agent перевіряється окремо у правилі
`flow/custom-user-agent-required` — це critical-вимога, винесена
зі цього rule у v2.1.0.)

## Як перевірити

1. Знайти branch, що виконується для non-organic (`!isOrganic` або
   еквівалент після перевірки referrer'а).
2. У цьому branch'і знайти HTTP POST виклик — будь-який клієнт
   (Ktor `client.post`, OkHttp `Request.Builder().post(...)`,
   Retrofit `@POST`). URL endpoint може бути літералом або
   результатом runtime-decrypt — обидва варіанти валідні.
3. Перевірити що body запиту містить:
   - значення UUID (із §3.2),
   - referrer string,
   - adId.

Якщо POST не існує для non-organic branch'а — критичний баг
(attribution не працює). Якщо POST існує але не містить одного з
трьох значень — `suspicious`. URL endpoint **не звіряється** ні з
чим — сам факт виявлення POST у non-organic branch'і задовольняє
правило.

## Як виглядає поломка

```kotlin
suspend fun startup() {
    val ref = referrerClient.fetch()
    val isOrganic = ref.contains("utm_medium=organic")
    if (!isOrganic) {
        // ❌ POST відсутній — adId і ref не передаються на бекенд
    }
    openWebView(uuid)
}
```

## Як виглядає правильно

```kotlin
suspend fun startup() {
    val ref = referrerClient.fetch()
    val isOrganic = ref.contains("utm_medium=organic")
    if (!isOrganic) {
        val adId = adIdClient.fetch()
        httpClient.post("https://domain.store/track") {
            header("User-Agent", System.getProperty("http.agent") ?: "Android")
            setBody(mapOf("uuid" to uuid, "ref" to ref, "adId" to adId))
        }
    }
    openWebView(uuid)
}
```

## Як доповідати

```
[flow/non-organic-post-required] SUSPICIOUS    (CRITICAL якщо POST відсутній взагалі)
  <file>:<line>
  Non-organic branch не виконує жодного POST-виклику з {uuid, ref, adId} | POST виконується, але body не містить <value>.
  Як виправити: додайте POST-виклик у non-organic branch з тілом, що містить uuid, ref, adId.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.6
```

## Виключення

Дозволено через `accepted-deviations`, якщо backend-флоу вимагає
іншу схему (наприклад, batch-POST через окремий сервіс). Обґрунтування
обов'язкове.
