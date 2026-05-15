---
id: webview/loadurl-after-initial
severity: observation
category: webview
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.6.0"
---

# Програмний `loadUrl(httpUrl)` поза lifecycle-init

## Інваріант

WebView повинен мати **один** programmatic точку входу в навігацію:
початковий `loadUrl(baseUrl)` (або `loadDataWithBaseURL(...)`),
який виконується в lifecycle-init блоку — `onCreate` / `onViewCreated`
/ Compose `factory` / `LaunchedEffect` для першого старту. Всі
наступні переходи між сторінками всередині WebView мають
відбуватися **через web-content** (кліки користувача, redirect'и
сервера, JS `window.location`), які перехоплюються `webViewClient`
через `shouldOverrideUrlLoading`. Якщо Android-сторона
програмно дзвонить `loadUrl("https://...")` **поза** init-блоком —
це маркер того, що навігація керується з нативного коду замість
web-content, що ускладнює перехоплення, ламає історію back-навігації
у WebView та виглядає підозріло для security-аудиту (схоже на
in-app browser, який підставляє URL'и довільно).

Це **observation**-правило: не блокує реліз. Звертає увагу на
архітектурний smell.

## Як перевірити

### Крок 1 — Зібрати всі виклики `loadUrl(...)` під `app/src/main/java/**/`

Включаючи `webView.loadUrl(...)`, `binding.webView.loadUrl(...)`,
`view.loadUrl(...)`, `loadDataWithBaseURL(...)`.

### Крок 2 — Класифікувати кожен виклик

Для кожного виклику `loadUrl(arg)`:

1. **Аргумент починається з `"javascript:"`** → JS-injection
   (читання localStorage, виклик глобальних JS-функцій з нативу).
   **Legit**, не flag'ити.
2. **Аргумент дорівнює `"about:blank"`** → стандартний паттерн
   перед `destroy()` для відв'язки renderer-процесу. **Legit**,
   не flag'ити.
3. **Аргумент — http(s)-URL** (літерал, BuildConfig, runtime-decrypt
   що повертає http(s)-URL) → подивитися, де знаходиться виклик:
   - У `override fun onCreate(...)` / `override fun onViewCreated(...)`
     / Compose `factory = { WebView(...).apply { loadUrl(...) } }` /
     `LaunchedEffect(Unit) { ... }` / Hilt `@Inject init` блоку →
     **це init-точка, не flag'ити**.
   - У `onPageFinished` / `onReceivedError` / `onError` callback'у
     `webViewClient` з тим самим baseUrl → **error-recovery / retry**,
     не flag'ити.
   - У `onResume` після перевірки `webView.url == null` → **retry
     after process-restore**, не flag'ити.
   - **Control flow походить з `WebChromeClient.onCreateWindow(...)`** —
     прямо у тілі override'а, або у inner-callback'у, створеному
     всередині `onCreateWindow` (типовий випадок: temp "capture"
     WebView з власним `WebViewClient.shouldOverrideUrlLoading`, яка
     forward'ить URL у parent через `parent.loadUrl(url)`). Це
     **канонічний Chromium multi-window forwarding** — обробка
     `window.open()` / `<a target="_blank">` коли Compose-AndroidView
     не вміє multi-window. Не flag'ити. Shape варіює (intermediate
     WebView vs. екстракція URL з `resultMsg`/`HitTestResult` напряму
     vs. інший варіант) — класифікуй за паттерном control-flow, а
     не за точним кодом.
   - У будь-якому іншому місці (button-handler, observer'у LiveData,
     coroutine-launch після API-відповіді, BroadcastReceiver-callback,
     navigation-callback з іншого екрану) → **flag як observation**.

### Крок 3 — Один finding на кожен виклик, який не пройшов крок 2

Per-call granularity: developer бачить точне місце і може оцінити,
чи це справді smell, чи свідома архітектура.

## Як виглядає поломка

```kotlin
class WebViewActivity : ComponentActivity() {
    private lateinit var webView: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        webView = WebView(this)
        webView.loadUrl(baseUrl)                         // ✅ init point — OK
        setContentView(webView)

        retryButton.setOnClickListener {
            webView.loadUrl(baseUrl)                     // ❌ button-handler
        }

        viewModel.navigateTo.observe(this) { url ->
            webView.loadUrl(url)                         // ❌ observer-driven nav
        }
    }
}
```

```kotlin
// Найгірше — навігація між landing'ом і privacy через Android
override fun onItemClick(item: MenuItem) {
    when (item.id) {
        R.id.privacy -> webView.loadUrl("$baseUrl/privacy")   // ❌
        R.id.terms   -> webView.loadUrl("$baseUrl/terms")     // ❌
    }
}
```

## Як виглядає правильно

```kotlin
class WebViewActivity : ComponentActivity() {
    private lateinit var webView: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        webView = WebView(this).apply {
            webViewClient = object : WebViewClient() {
                override fun onReceivedError(...) {
                    loadUrl(baseUrl)                     // ✅ error-recovery
                }
            }
            loadUrl(baseUrl)                             // ✅ єдина init-точка
        }
        setContentView(webView)
        // Privacy / terms навігація — через <a href> у web-content,
        // перехоплюється webViewClient.shouldOverrideUrlLoading.
    }

    override fun onDestroy() {
        webView.loadUrl("about:blank")                   // ✅ pre-destroy
        webView.destroy()
        super.onDestroy()
    }
}
```

## Як доповідати

```
[webview/loadurl-after-initial] OBSERVATION
  <file>:<line>
  Програмний `loadUrl("<URL-preview>")` поза lifecycle-init блоком (знаходиться у <button-handler | LiveData observer | coroutine | callback>). Навігація між сторінками всередині WebView має йти через web-content (кліки → `shouldOverrideUrlLoading`), а не через нативну сторону — інакше webViewClient не отримує контроль над переходом, ламається back-history WebView, і виглядає як in-app browser, що довільно підставляє URL'и (security-smell).
  Як виправити: винесіть навігацію у web-сторону (`<a href>` у HTML, або `window.location` у JS), і дозвольте `webViewClient.shouldOverrideUrlLoading` перехопити, якщо потрібно нативне втручання. Якщо це навмисний retry/refresh — додайте `accepted-deviations` з обґрунтуванням.
  Див.: https://developer.android.com/develop/ui/views/layout/webapps/load-local-content
```

## Виключення

Дозволено через `accepted-deviations` для конкретного callsite (або
для правила в цілому), якщо команда свідомо керує навігацією
з Android-сторони (наприклад, hybrid-architecture, де native UI
вибирає сторінку для WebView). Формат:

```
webview/loadurl-after-initial:com/example/ui/WebViewHost.kt:42: navigation керується Android-side свідомо, web-content цього URL'у не знає
```

Або глобально для всього файлу:

```
webview/loadurl-after-initial:com/example/ui/WebViewHost.kt: hybrid architecture; nav-state живе у ViewModel
```
