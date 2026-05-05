---
id: flow/redirect-method-correctness
severity: suspicious
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
дозволених методів**, обраний у CLAUDE.md `redirect-method`:

- **7.1 webMessageListener** — `WebViewCompat.addWebMessageListener`
  з обмеженням origin'у через `allowedOriginRules`. Web сторона
  надсилає через `appBridge.postMessage(...)`. Android слухає, валідує
  origin, парсить команду.
- **7.2 consoleLog** — `WebChromeClient.onConsoleMessage()` парсить
  повідомлення вигляду `APP_ACTION: GO_GAME`.
- **7.3 shouldOverrideUrlLoading** — Privacy Policy визначається за
  ознакою "не виклинуто `shouldOverrideUrlLoading` до `onPageStarted`".

Плагін перевіряє коректність **тільки** методу із CLAUDE.md, не
шукає всі.

## Як перевірити

1. Прочитати `redirect-method` з `.claude/CLAUDE.md`. Якщо порожнє і
   `landing-mechanism` = `webview` → finding `suspicious` "redirect-method
   не задекларовано". Пропустити решту перевірки.
2. Якщо `landing-mechanism` = `none` або `custom-tabs` — пропустити правило
   повністю (Skipped rules).
3. Залежно від `redirect-method`:
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
4. Якщо очікуваний метод не знайдений — `suspicious`.
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
[flow/redirect-method-correctness] SUSPICIOUS    (CRITICAL якщо origin не валідується для 7.1)
  <file>:<line>
  Метод <7.1 webMessageListener | 7.2 consoleLog | 7.3 shouldOverrideUrlLoading> <не знайдено | реалізовано без валідації origin/frame | wildcard в allowedOriginRules>.
  Як виправити: <specific guidance per method, see §3.7 спецификації>.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.7
```

## Виключення

Дозволено через `accepted-deviations`, якщо команда тестує
експериментальний метод поза 7.1/7.2/7.3 (наприклад, 7.4 onPageFinished).
Обґрунтування обов'язкове.
