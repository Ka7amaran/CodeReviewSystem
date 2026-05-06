---
id: perf/webview-pitfalls
severity: observation
category: perf
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.1.0"
---

# WebView UX і performance підводні камні

## Інваріант

Поза hard-вимогами `webview/config-completeness` (які блокують
функціональність), є набір UX/performance паттернів, які роблять
WebView-flow помітно гіршим без явної поломки. Це observation-правило:
збирає такі паттерни в один список.

Це **observation**-правило: ніколи не блокує реліз. Просто звертає
увагу developer'а на актуальні шляхи покращення.

## Як перевірити

Для кожного WebView-instance перевірити такі паттерни:

1. **Cookies очищаються між сесіями.** Шукати виклики
   `CookieManager.getInstance().removeAllCookies(...)` або
   `WebStorage.getInstance().deleteAllData()` в `onCreate` /
   `onResume` / `onDestroy`. Якщо є — observation: "користувач
   ре-логіниться у Google/Facebook/Apple OAuth кожного запуску".
2. **Hardware acceleration не виставлене.** `setLayerType(LAYER_TYPE_HARDWARE, null)`
   відсутній у setup. Це покривається `webview/config-completeness`
   як suspicious; тут — додатковий observation з конкретним
   симптомом ("janky scrolling, drop frames на gameplay-related
   animations при scroll'і у WebView").
3. **Кеш не використовується.** `cacheMode = LOAD_NO_CACHE` або
   `LOAD_CACHE_ONLY` замість `LOAD_DEFAULT`. Кожен старт ре-завантажує
   повністю — на повільному з'єднанні landing-page показується через
   2-5 сек замість 200ms.
4. **File upload без progress indicator.** `onShowFileChooser`
   присутній (тобто upload реалізований), але немає UI-feedback'у
   (`ProgressBar` / `LoadingIndicator`) під час upload'у. Великі
   фото >5MB йдуть мовчки 10-30 сек, юзер думає що зависло.
5. **Camera permission запитується занадто рано.** `requestPermissions`
   викликається в `onCreate` Activity, не в момент натискання кнопки
   "вибрати фото". Це знижує acceptance rate на 30-40% (юзер
   відмовляє "на всяк випадок").
6. **`WebView.destroy` не викликається в `onDestroy` Activity.**
   Memory leak — WebView утримує Context, після rotation чи
   recreate накопичується кілька mb пам'яті.

Кожна знайдена точка — окремий observation з конкретним симптомом.

## Як виглядає поломка

```kotlin
class WebViewActivity : ComponentActivity() {
    private lateinit var webView: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // ❌ camera permission на старті, не at point-of-need
        ActivityCompat.requestPermissions(this, arrayOf(CAMERA), 0)

        webView = WebView(this).apply {
            settings.cacheMode = WebSettings.LOAD_NO_CACHE   // ❌ no cache
        }
        CookieManager.getInstance().removeAllCookies(null)   // ❌ wipe cookies
        setContentView(webView)
    }

    // ❌ webView.destroy() відсутній → memory leak на rotation
}
```

## Як виглядає правильно

```kotlin
class WebViewActivity : ComponentActivity() {
    private lateinit var webView: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        webView = WebView(this).apply {
            settings.cacheMode = WebSettings.LOAD_DEFAULT     // ✅ enable cache
            setLayerType(LAYER_TYPE_HARDWARE, null)           // ✅ hardware accel
            webChromeClient = object : WebChromeClient() {
                override fun onShowFileChooser(...): Boolean {
                    // ✅ permission requested only when user clicks <input type="file">
                    if (cameraNeeded && !hasCameraPermission()) {
                        requestCameraPermission()
                        return false
                    }
                    showProgressIndicator()                   // ✅ UI feedback
                    // ... upload logic
                }
            }
        }
        // НЕ wipe cookies — переюз session з попереднього запуску
        setContentView(webView)
    }

    override fun onDestroy() {
        webView.destroy()                                     // ✅ release resources
        super.onDestroy()
    }
}
```

## Як доповідати

```
[perf/webview-pitfalls] OBSERVATION
  <file>:<line>
  WebView pitfall: <cookies cleared each launch | hardware accel off | cache disabled | file upload без progress | camera permission too early | WebView.destroy missing>. Симптом для користувача: <re-login each time | janky scroll | slow second visit | "frozen" during upload | low permission acceptance | memory leak after rotation>.
  Як виправити: <конкретна порада в одному реченні>.
  Див.: https://developer.android.com/develop/ui/views/layout/webapps/webview
```

## Виключення

Дозволено через `accepted-deviations` для конкретного pitfall'а, якщо
поведінка свідома (наприклад, cookies wipe вимагається бізнес-логікою —
кожен запуск як свіжий юзер). Обґрунтування обов'язкове.
