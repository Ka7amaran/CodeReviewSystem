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
`utm_medium=organic`) усі три атрибуційні значення — **UUID**,
**referrer** і **adId (gaid)** — мають **дійти до бекенду** при
запуску. Спосіб доставки (transport) вторинний; інваріант захищає
факт, що три значення потрапляють на сервер, а не конкретний виклик
`client.post`.

URL/домен бекенду **визначається з коду** (Stage 0 валідатора). Він
може бути літеральним (`"https://x.store/track"`), або зашифрованим
at rest (`.dec(...)` / XOR-Base64 / AES — типовий team-pattern).
Зашифрований URL — НЕ привід для finding'а; це очікуваний патерн.

### Каталог відомих механізмів доставки (розширюваний, не вичерпний)

1. **HTTP POST** — `client.post(...)` (Ktor / OkHttp / Retrofit /
   HttpURLConnection) з тілом, що містить три значення
   (`{uuid, ref, adId}`; точні ключі узгоджуються з бекендом).
   Дефолтний, найпоширеніший варіант.
2. **Зашифрований cookie на голому домені** — апка кладе три значення
   у зашифрований cookie і завантажує **голий бекенд-домен** у WebView;
   окремого POST-запиту немає, сервер читає cookie server-side.
   Типова форма: AES-blob (напр. `candySeal`) у cookie `kex` із парами
   `{keyu=uuid, keyref=referrer, keya=gaid}`, встановлений через
   `CookieManager.setCookie(domain, ...)` перед `loadUrl(<домен>)`.
   Значення часто **розщеплені за timing'ом**: `uuid` освіжається
   щозапуску, `gaid`+`referrer` кладуться лише на першому запуску
   (`isFirstLaunch`). Це задовольняє інваріант — кожне з трьох значень
   хоч раз доходить до бекенду.

Будь-який інший transport, що доставляє три значення (query-параметри
в URL `?u=&ref=&aid=`, custom header, tracking-pixel тощо), теж
валідний. Механізм **поза цим каталогом**, який усе ж доставляє три
значення, — не поломка, а привід для `OBSERVATION` + запис у каталог
(див. «Як доповідати»), НЕ `CRITICAL`.

(User-Agent перевіряється окремо у правилі
`flow/custom-user-agent-required` — це critical-вимога, винесена
з цього rule у v2.1.0.)

## Як перевірити

1. Знайти branch, що виконується для non-organic (`!isOrganic` або
   еквівалент після перевірки referrer'а).
2. У цьому branch'і (або на стартовому шляху) знайти **transport**,
   що доставляє три значення на бекенд — за каталогом вище:
   - **POST**: `client.post` / `Request.Builder().post(...)` /
     `@POST` з body, що містить три значення.
   - **Cookie**: `CookieManager.setCookie(domain, "<name>=<blob>")`
     (часто безпосередньо перед `webView.loadUrl(<голий домен>)`), де
     `<blob>` — зашифроване payload'. Простежити dataflow blob'а
     назад до місця шифрування: чи в нього кладуться uuid + referrer
     + adId?
   URL endpoint/домен може бути літералом або результатом
   runtime-decrypt — обидва варіанти валідні.
3. Перевірити, що transport передає всі три значення:
   - значення UUID (із §3.2),
   - referrer string,
   - adId (gaid).
   **Timing-розщеплення допустиме**: якщо `uuid` іде щозапуску, а
   `gaid`+`referrer` кладуться лише на першому запуску (cookie-варіант),
   інваріант виконується — важливо, що кожне значення хоч раз доходить
   до бекенду, а не що всі три в одному запиті.

Якщо **жоден** transport не доставляє атрибуцію для non-organic
branch'а — критичний баг (attribution не працює). Якщо transport є,
але не містить одного з трьох значень — `suspicious`. Якщо знайдено
transport поза каталогом, що все ж доставляє три значення —
`OBSERVATION` (не поломка). URL endpoint/домен **не звіряється** ні з
чим — сам факт доставки трьох значень у non-organic branch'і
задовольняє правило.

## Як виглядає поломка

```kotlin
suspend fun startup() {
    val ref = referrerClient.fetch()
    val isOrganic = ref.contains("utm_medium=organic")
    if (!isOrganic) {
        // ❌ жодного transport'а — ні POST, ні cookie;
        //    adId і ref нікуди не доходять
    }
    openWebView(uuid)
}
```

## Як виглядає правильно

**Варіант POST** (три значення у тілі запиту):

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

**Варіант cookie-transport** (три значення у зашифрованому cookie;
завантажується голий домен, сервер читає cookie):

```kotlin
suspend fun startup() {
    val ref = referrerClient.fetch()
    if (!ref.contains("utm_medium=organic") && isFirstLaunch) {
        val adId = adIdClient.fetch()
        // candySeal = AES/CBC + IV + Base64 → зашифрований blob
        val blob = candySeal.encrypt("keyu=$uuid&keyref=$ref&keya=$adId")
        CookieManager.getInstance().setCookie(domain, "kex=$blob")
    }
    webView.loadUrl(domain)   // голий бекенд-домен; сервер читає cookie
}
```

## Як доповідати

**CRITICAL** — жоден transport не доставляє атрибуцію:
```
[flow/non-organic-post-required] CRITICAL
  <file>:<line>
  Non-organic branch не доставляє атрибуцію на бекенд жодним механізмом (ні POST, ні cookie, ні інший) — {uuid, ref, adId} не потрапляють на сервер.
  Як виправити: додайте transport (POST-виклик АБО cookie на голому домені) з трьома значеннями uuid, ref, adId.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.6
```

**SUSPICIOUS** — transport є, але бракує значення:
```
[flow/non-organic-post-required] SUSPICIOUS
  <file>:<line>
  Transport атрибуції (<POST|cookie>) виконується, але не передає <value>.
  Як виправити: додайте <value> у payload/cookie transport'а.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.6
```

**OBSERVATION** — transport поза каталогом, інваріант виконується
(cookie вже у каталозі — цей блок лише для дійсно нових механізмів):
```
[flow/non-organic-post-required] OBSERVATION
  <file>:<line>
  Знайдено новий патерн доставки атрибуції поза каталогом (<опис механізму>): три значення {uuid, ref, adId} доходять до бекенду через <механізм>. Інваріант виконується. Якщо це свідомий team-патерн — додайте механізм у каталог `rules/flow/non-organic-post-required.md`.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.6
```

## Виключення

Дозволено через `accepted-deviations`, якщо backend-флоу вимагає
іншу схему (наприклад, batch-POST через окремий сервіс). Обґрунтування
обов'язкове.
