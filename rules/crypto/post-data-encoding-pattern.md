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

# Raw attribution values не з'являються у HTTP wire як plaintext

## Інваріант

Дані, що відправляються в attribution-POST (endpoint виявлений у
non-organic branch'і за §3.6), **не повинні з'являтись у HTTP wire
як plaintext**. Між побудовою payload'у і фактичним викликом
`httpClient.post(...)` (або еквівалентом) повинна існувати щонайменше
одна **transformation step**, яка приховує raw values від мережевого
sniffer'а: AES/RSA encryption, hash-based MAC, custom serialization з
обфускацією, NDK-based encoding, тощо.

**Що не пиниться:**
- Конкретний алгоритм (AES vs RSA vs кастом — все валідне).
- Як саме готується payload **до** transformation step (URL-encoding
  одного поля, raw concatenation іншого — це internal layout payload'у,
  не плагіна справа; як backend парсить декриптований blob — окремий
  контракт з backend'ом).
- Чи різні POST endpoint'и використовують різні transformation
  patterns (deliberate per-endpoint design валідний).

Файли і класи, що реалізують кодування, можуть бути будь-де у
кодовій базі — плагін НЕ привʼязується до шляхів типу
`*.crypto.*` чи `*.settings.*`.

## Як перевірити

1. Знайти attribution-POST виклик у non-organic branch'і (Stage 0
   валідатора вже виявив його як частину детекції `backend-domain`).
2. Простежити origin тіла запиту: яка функція готує body? Який
   ланцюг трансформацій застосовується **між моментом, коли raw
   values потрапляють у код, і моментом, коли `setBody(...)` /
   `Request.post(body)` отримує final payload**?
3. Перевірити, що цей ланцюг містить хоча б одну **transformation
   step** (виклики `Cipher`, `Mac`, `MessageDigest`, AES/Base64/HMAC
   через будь-яку бібліотеку, NDK-based encrypt, custom obfuscation
   function), яка робить raw values нерозпізнаваними у тілі запиту.
4. Якщо raw values **напряму** серіалізуються у JSON / form-data
   без жодної transformation step → finding `suspicious` "raw values
   досягають wire у plaintext".
5. Internal heterogeneity payload'у (одне поле URL-encoded, інше raw)
   **до** transformation step — **не finding**. Wire бачить тільки
   результат transformation step.

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
  <file>:<line>   (POST-виклик або body-builder функція)
  Attribution-POST надсилає raw values у HTTP wire як plaintext — між побудовою payload'у і `httpClient.post(...)` не виявлено жодної transformation step (encryption / MAC / obfuscation). UUID/ref/adId видно у sniffer'і без декриптування.
  Як виправити: додайте transformation step між побудовою body і викликом HTTP. Конкретний алгоритм/бібліотека на ваш розсуд — AES+Base64, HMAC, custom obfuscation, NDK encode — будь-що, що робить raw values нерозпізнаваними на wire.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.10
```

## Виключення

Дозволено через `accepted-deviations`, якщо бекенд навмисно
очікує plain-JSON або інший формат. Обґрунтування обов'язкове —
поясніть, чому кодування не використовується.
