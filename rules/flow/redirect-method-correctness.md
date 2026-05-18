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

# Перехід із Privacy Policy у гру реалізовано і працює

## Інваріант

Після завантаження Privacy Policy у WebView, control eventually
reaches **in-app game destination** (`navController.navigate(<game>)`,
`startActivity(<game-Activity>)`, Compose state change на game-екран,
або інший in-app navigation call). Метод досягнення цієї end-state
**може бути будь-яким** — рішення команди / архітектура / experimental
підхід.

Мета правила: переконатись, що цей контракт дійсно виконується (тобто
існує реальний path від WebView callback'у до in-app навігації), а не
дотриматись конкретного шаблону реалізації.

## Каталог відомих патернів

Список механізмів, які команда вже використовувала. **Це extensible
catalog, не closed list** — якщо знайдено новий механізм, що
задовольняє інваріант, він surfaces як `OBSERVATION` для додавання
сюди.

- **7.1 webMessageListener** — `WebViewCompat.addWebMessageListener`
  з обмеженням origin'у через `allowedOriginRules`. Web-сторона
  надсилає через `appBridge.postMessage(...)`. Android слухає, валідує
  origin, парсить команду → in-app nav.
- **7.2 consoleLog** — `WebChromeClient.onConsoleMessage()` парсить
  повідомлення вигляду `APP_ACTION: GO_GAME` → in-app nav.
- **7.3 shouldOverrideUrlLoading (in-app target)** — `WebViewClient.
  shouldOverrideUrlLoading` з custom-scheme (e.g., `app://`) або
  URL-match, тіло якого виконує in-app nav. NOT counted: deep-link
  routers, що ведуть тільки у `Intent.ACTION_VIEW` для external
  schemes (`mailto:`, `tel:`, `whatsapp://`, etc.).
- **7.4 onReceivedTitle** — `WebChromeClient.onReceivedTitle` з
  title-match (e.g., `if (title == "Privacy & Policies | <app>")
  navigateGame()`).
- **7.5 onPageFinished / onPageStarted** — `WebViewClient.onPageFinished`
  (або `onPageStarted`) з URL/title match → in-app nav.

Якщо команда винайшла 7.6+ — додайте сюди після того, як OBSERVATION
підкаже патерн.

## Як перевірити

Це правило споживає `landing-mechanism` і `redirect-method`,
обчислені у Stage 0 валідатором.

1. Якщо `landing-mechanism ∈ {custom-tabs, none}` — пропустити правило
   повністю (CustomTabs не редіректить через Privacy Policy у гру —
   ця механіка специфічна для WebView). Reason: "не WebView".
2. Якщо `landing-mechanism ∈ {webview, both}`, перейти до dataflow
   trace: знайти WebView-instance (з Stage 0), перебрати усі
   callback'и/listener'и, що до нього приєднані (`WebChromeClient`,
   `WebViewClient`, `WebMessageListener`, повний набір override'нутих
   методів). Для кожного callback'у простежити, чи його тіло (прямо
   або транзитивно) досягає **in-app navigation call**:
   - `navController.navigate(<destination>)` де destination — in-app
     екран (game / home / settings, не WebView-маршрут).
   - `startActivity(Intent(context, <InAppActivity>::class.java))`.
   - Compose state change, що змінює UI на game-екран
     (через `mutableStateOf` / `viewModel.navigateGame()` / тощо).
3. Класифікувати знайдені шляхи:
   - **0 шляхів** до in-app навігації → `CRITICAL` "у коді не знайдено
     жодного механізму переходу Privacy Policy → in-app destination;
     інваріант порушено".
   - **≥1 шлях через catalog pattern** (7.1-7.5) → перейти до кроку 4
     (верифікація конкретного pattern'у).
   - **Шлях через novel pattern** (callback не з каталогу, але дійсно
     веде до in-app nav) → `OBSERVATION` "знайдено новий метод
     redirect (<callback-name>); інваріант виконується; додайте до
     каталогу у `rules/flow/redirect-method-correctness.md §Каталог
     відомих патернів` якщо це свідомий team-pattern".
   - **2+ шляхів через catalog patterns**, які ОБИДВА реально
     запускаються і ведуть до in-app nav (не один-real-другий-stub)
     → `SUSPICIOUS` "знайдено кілька активних redirect-механізмів
     одночасно — імовірно надлишковий код".
4. Верифікація конкретного catalog-pattern'у:
   - **7.1**: перевірити, що `allowedOriginRules` непорожній і не
     містить wildcard `*`. Перевірити, що `onPostMessage` валідує
     `sourceOrigin` і `isMainFrame`. Без валідації → `CRITICAL`
     (security issue, не closed-list issue).
   - **7.2-7.5**: переконатись, що тіло callback'у дійсно досягає
     in-app nav, а не просто matches без навігації.
5. Якщо catalog-pattern реалізовано коректно — правило проходить
   (✅ у "Перевірені інваріанти").

### Як відрізнити catalog-pattern 7.3 від deep-link router'а

`shouldOverrideUrlLoading` часто живе у проєкті **не** як redirect-метод,
а як обробник зовнішніх схем (`mailto:`, `tel:`, `whatsapp://`,
`viber://`, `tg://`, `intent://`, `market://`, `geo:`, банківські).
Це — **deep-link router**, не redirect-метод. Розрізнення:

| Що робить тіло після scheme-match | Класифікація |
|---|---|
| `Intent(Intent.ACTION_VIEW, uri).also { startActivity(it) }` (зазвичай у `try/catch ActivityNotFoundException`) | deep-link router — НЕ redirect |
| `navController.navigate(...)` / `startActivity(<in-app Activity>)` / іншу in-app навігацію | 7.3 redirect |

Якщо ВСІ scheme-branches у `shouldOverrideUrlLoading` закінчуються
external `startActivity(Intent.ACTION_VIEW)` — це чистий deep-link
router; цей override НЕ рахується серед redirect-механізмів.

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

**CRITICAL** (інваріант порушено):
```
[flow/redirect-method-correctness] CRITICAL
  <file>:<line>   (WebView-instance або найближче місце, де redirect мав би бути)
  У коді не знайдено жодного механізму переходу Privacy Policy → in-app destination. Жоден WebView callback не досягає `navController.navigate(<in-app>)` / `startActivity(<in-app>)`. Інваріант: після завантаження Privacy Policy юзер має потрапити у гру.
  Як виправити: реалізуйте перехід через будь-який з catalog-patterns (7.1 addWebMessageListener, 7.2 onConsoleMessage, 7.3 shouldOverrideUrlLoading з in-app target, 7.4 onReceivedTitle, 7.5 onPageFinished + URL/title match) АБО через свій механізм — головне, щоб з якогось WebView callback'у дійсно викликався in-app navigation.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.7
```

**OBSERVATION** (novel mechanism, інваріант виконується):
```
[flow/redirect-method-correctness] OBSERVATION
  <file>:<line>   (callback override, що виконує перехід)
  Знайдено новий патерн redirect: `<callback-name>` (поза каталогом 7.1-7.5). Інваріант правила виконується — перехід Privacy Policy → in-app навігація працює. Якщо це свідомий team-патерн, додайте у каталог відомих механізмів у `rules/flow/redirect-method-correctness.md §Каталог відомих патернів`.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.7
```

**SUSPICIOUS** (2+ catalog-patterns активні):
```
[flow/redirect-method-correctness] SUSPICIOUS
  <file>:<line>
  Знайдено кілька активних redirect-механізмів одночасно: <patternA у file:line> + <patternB у file:line>. Обидва ведуть до in-app navigation — імовірно надлишковий код, що ускладнює maintenance.
  Як виправити: залишити один основний механізм; інші прибрати або задекларувати у `accepted-deviations` з поясненням ролі.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.7
```

**CRITICAL** (catalog-pattern знайдено, але без валідації — для 7.1):
```
[flow/redirect-method-correctness] CRITICAL
  <file>:<line>
  Метод 7.1 (addWebMessageListener) реалізовано без валідації origin/frame, або `allowedOriginRules` містить wildcard `*`. Будь-яка сторінка може ініціювати перехід у гру.
  Як виправити: <конкретно>.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.7
```

## Виключення

Дозволено через `accepted-deviations`, якщо команда тестує
експериментальний метод поза 7.1/7.2/7.3 (наприклад, 7.4 onPageFinished).
Обґрунтування обов'язкове.
