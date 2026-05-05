---
id: crypto/post-data-encoding-pattern
severity: suspicious
category: crypto
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
requires-project-type: with-attribution
---

# Дані POST-запиту проходять через єдиний патерн кодування

## Інваріант

Дані, що відправляються в POST на `backend-domain` (з §3.6), мають
проходити через єдиний патерн кодування проєкту (зазвичай
AES + Base64 URL-safe, але точний алгоритм не важливий — важливо що
**один і той самий патерн** використовується послідовно).

Файли і класи, що реалізують кодування, можуть бути будь-де у
кодовій базі — плагін НЕ привʼязується до шляхів типу
`*.crypto.*` чи `*.settings.*`.

## Як перевірити

1. Знайти POST-виклик до backend-домену (з §3.6 dataflow).
2. Простежити origin тіла запиту: яка функція готує body? Який
   ланцюг трансформацій застосовується до raw values UUID/ref/adId
   до моменту виклику HTTP?
3. Перевірити, що цей ланцюг містить **криптографічну операцію**
   (виклики `Cipher`, `Mac`, `MessageDigest`, або
   еквіваленти AES/Base64/HMAC через будь-яку бібліотеку).
4. Якщо raw values напряму серіалізуються в JSON без кодування —
   finding `suspicious` (можливо проєкт навмисно so, але треба
   переглянути).
5. Якщо знайдено кілька різних кодувальних патернів у різних
   POST-викликах — finding `suspicious` (несумісність).

## Як виглядає поломка

```kotlin
suspend fun postAttribution(uuid: String, ref: String, adId: String) {
    httpClient.post("https://domain.store/track") {
        setBody(mapOf("uuid" to uuid, "ref" to ref, "adId" to adId))
        // ❌ Plain JSON, без кодування. Бекенд очікує encoded payload.
    }
}
```

## Як виглядає правильно

```kotlin
class PayloadEncoder(private val key: ByteArray) {
    fun encode(uuid: String, ref: String, adId: String): String {
        val plain = """{"uuid":"$uuid","ref":"$ref","adId":"$adId"}"""
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding").apply {
            init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), IvParameterSpec(iv))
        }
        val encrypted = cipher.doFinal(plain.toByteArray())
        return Base64.encodeToString(encrypted, Base64.URL_SAFE or Base64.NO_WRAP)
    }
}

suspend fun postAttribution(uuid: String, ref: String, adId: String) {
    val payload = encoder.encode(uuid, ref, adId)
    httpClient.post("https://domain.store/track") {
        setBody(mapOf("payload" to payload))    // ✅ encoded
    }
}
```

## Як доповідати

```
[crypto/post-data-encoding-pattern] SUSPICIOUS
  <file>:<line>   (POST-виклик або encoder-функція)
  POST на backend-домен надсилає <plain-text body | дані з різними патернами кодування у різних викликах>.
  Як виправити: проведіть UUID/ref/adId через єдиний кодувальний патерн перед відправкою. Конкретний алгоритм/бібліотека не важливі — важливо що один і той самий патерн усюди.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.10
```

## Виключення

Дозволено через `accepted-deviations`, якщо бекенд навмисно
очікує plain-JSON або інший формат. Обґрунтування обов'язкове —
поясніть, чому кодування не використовується.
