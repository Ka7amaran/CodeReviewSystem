---
id: flow/redirect-method-correctness
severity: critical
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
requires-project-type: with-attribution
---

# Метод переходу Privacy Policy → game реалізовано коректно

## Інваріант

Перехід із Privacy Policy у гру виконується через **один із трьох
дозволених методів**:

- **7.1 webMessageListener** — `WebViewCompat.addWebMessageListener`
  з обмеженням origin'у через `allowedOriginRules`. Web сторона
  надсилає через `appBridge.postMessage(...)`. Android слухає, валідує
  origin, парсить команду.
- **7.2 consoleLog** — `WebChromeClient.onConsoleMessage()` парсить
  повідомлення вигляду `APP_ACTION: GO_GAME`.
- **7.3 shouldOverrideUrlLoading** — Privacy Policy визначається за
  ознакою "не виклинуто `shouldOverrideUrlLoading` до `onPageStarted`".

Метод **визначається з коду** (Stage 0), не з CLAUDE.md. Якщо у коді
рівно один — перевіряється його коректність. Якщо нуль — це
CRITICAL (немає переходу). Якщо два і більше — SUSPICIOUS (надлишок).

## Як перевірити

Це правило споживає `landing-mechanism` і `redirect-method`,
обчислені у Stage 0 валідатором.

1. Якщо `landing-mechanism ∈ {custom-tabs, none}` — пропустити правило
   повністю (CustomTabs не редіректить через Privacy Policy у гру —
   ця механіка специфічна для WebView). Reason: "не WebView".
2. Якщо `landing-mechanism ∈ {webview, both}`, дивитись на
   `redirect-method` (Stage 0):
   - **`(none)`** (0 знайдено) → finding `critical`
     "у коді не знайдено жодного з методів 7.1/7.2/7.3 — Privacy
     Policy не може передати юзера у гру". Зупинити.
   - **`(multiple)`** (2+ знайдено) → finding `suspicious`
     "знайдено кілька методів одночасно — імовірно надлишковий
     код, який потрібно почистити". Зупинити.
   - **`7.1` / `7.2` / `7.3`** (рівно один) → перейти до кроку 3.
3. Залежно від виявленого методу:
   - **7.1**: знайти виклик `WebViewCompat.addWebMessageListener(...)`.
     Перевірити, що `allowedOriginRules` непорожній і не містить
     wildcard `*`. Перевірити, що `WebMessageListener.onPostMessage`
     валідує `sourceOrigin` і `isMainFrame`.
   - **7.2**: знайти override `WebChromeClient.onConsoleMessage`.
     Перевірити, що тіло парсить очікуваний префікс
     (наприклад, `APP_ACTION:`).
   - **7.3**: знайти override `WebViewClient.shouldOverrideUrlLoading`
     і `onPageStarted`. Перевірити, що логіка визначає Privacy Policy
     за відсутністю `shouldOverrideUrlLoading` до `onPageStarted`.
4. Якщо метод реалізовано коректно — правило проходить (✅ у
   "Перевірені інваріанти").
5. Якщо знайдений, але без валідації origin (для 7.1) → `critical`
   (security issue).

## Як виглядає поломка (приклад для 7.1)

```kotlin
WebViewCompat.addWebMessageListener(
    webView,
    "appBridge",
    setOf("*"),                         // ❌ wildcard origin
    object : WebViewCompat.WebMessageListener {
        override fun onPostMessage(
            view: WebView,
            message: WebMessageCompat,
            sourceOrigin: Uri,
            isMainFrame: Boolean,
            replyProxy: JavaScriptReplyProxy
        ) {
            navigateToGame()             // ❌ без перевірки origin/frame
        }
    }
)
```

## Як виглядає правильно (приклад для 7.1)

```kotlin
val allowedOrigins = setOf("https://domain.store")

WebViewCompat.addWebMessageListener(
    webView,
    "appBridge",
    allowedOrigins,
    object : WebViewCompat.WebMessageListener {
        override fun onPostMessage(
            view: WebView,
            message: WebMessageCompat,
            sourceOrigin: Uri,
            isMainFrame: Boolean,
            replyProxy: JavaScriptReplyProxy
        ) {
            if (sourceOrigin.toString() != "https://domain.store") return
            if (!isMainFrame) return
            if (message.data == "GO_GAME") navigateToGame()
        }
    }
)
```

## Як доповідати

```
[flow/redirect-method-correctness] CRITICAL | SUSPICIOUS
  <file>:<line>   (точка реалізації або найближче місце де метод мав би бути)
  <у коді не знайдено жодного з методів 7.1/7.2/7.3 — CRITICAL>
  | <знайдено кілька методів одночасно (X+Y) — імовірно надлишковий код — SUSPICIOUS>
  | <метод 7.1 реалізовано без валідації origin/frame | wildcard в allowedOriginRules — CRITICAL>
  | <метод 7.2 реалізовано, але тіло не парсить очікуваний префікс — SUSPICIOUS>
  | <метод 7.3 реалізовано, але без логіки розрізнення Privacy Policy і game URL — SUSPICIOUS>.
  Як виправити: <specific guidance per case>.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.7
```

## Виключення

Дозволено через `accepted-deviations`, якщо команда тестує
експериментальний метод поза 7.1/7.2/7.3 (наприклад, 7.4 onPageFinished).
Обґрунтування обов'язкове.
