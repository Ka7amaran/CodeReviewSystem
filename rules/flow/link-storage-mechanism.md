---
id: flow/link-storage-mechanism
severity: observation
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.10.0"
requires-project-type: with-attribution
---

# Тип збереження landing-посилання: tracker vs final

## Інваріант

Апка з attribution-flow зберігає landing-URL між сесіями за однією з
двох стратегій — і ця стратегія має бути **очевидно видна рецензенту
в шапці звіту**, поруч із `landing-mechanism` та `redirect-method`:

- **`tracker`** — на сервер прив'язується `(uuid → real-landing-url)`,
  апка щозапуску відкриває `https://<наш-домен>/<uuid>` і бекенд сам
  виконує редірект-ланцюг. Підходить будь-якому `landing-mechanism`;
  для CustomTabs — **єдиний** можливий варіант (CustomTabs не дає
  WebView-callback-ів для перехоплення URL з redirect-ланцюга).
- **`final`** — апка локально зберігає **останню URL з redirect-ланцюга**,
  перехоплену через WebView callback (`doUpdateVisitHistory`,
  `shouldOverrideUrlLoading`, `onPageStarted`, `onPageFinished`,
  `onPageCommitVisible`, `onReceivedTitle`, `onProgressChanged`) у
  SharedPreferences / DataStore / Room / File. Наступні запуски —
  відкривають збережену URL **напряму, без бекенду**. Можлива лише
  для WebView.

Це **observation**-правило: ніколи не блокує реліз. Мета — щоб
рецензент бачив у шапці звіту, який саме варіант реалізовано.

## Як перевірити

Stage 0 у валідаторі вже обчислив `landing-mechanism`. Це правило
використовує цей результат і добиває `link-storage`:

1. **`landing-mechanism = custom-tabs`** → `link-storage = tracker`
   беззаперечно. CustomTabs не дозволяє перехопити URL із
   redirect-ланцюга, тому збереження може бути тільки серверне.
   - Підтвердження (опціонально): пройтись по network-клієнтах
     (Retrofit / OkHttp / Ktor) і знайти GET/POST з UUID-параметром
     (`/track/<uuid>`, `?uuid=...`) — це доводить tracker і знайдений
     URL прикладається як evidence.
   - Emit OBSERVATION з `link-storage = tracker (CustomTabs)`.

2. **`landing-mechanism ∈ {webview, both}`** → dataflow trace:
   - Знайти WebView-instance(и); перебрати всі callback override-и:
     `WebViewClient.{doUpdateVisitHistory, shouldOverrideUrlLoading,
     onPageStarted, onPageFinished, onPageCommitVisible}` та
     `WebChromeClient.{onReceivedTitle, onProgressChanged}`.
   - Для кожного callback-у простежити: чи URL/title-аргумент
     потрапляє у persistent storage? Маркери:
     - **SharedPreferences**: `.edit().putString(...).apply()`,
       `.edit { putString(...) }`.
     - **DataStore**: `.edit { it[key] = url }`,
       `dataStore.updateData { ... }`, `preferencesOf(...)`.
     - **Room**: будь-який DAO `@Insert` / `@Update` з URL-полем.
     - **File / file-based KV**: `.writeText(...)`,
       `FileOutputStream(...).write(...)`.
   - Перевірити **read-on-launch**: чи entry-point (splash /
     launcher Activity / `Application.onCreate`) читає той самий
     storage-ключ і відкриває WebView/CustomTabs з тією URL?
   - Класифікація:
     - Save-callback + read-on-launch → **`final`**. Evidence:
       callback (`<file>:<line>`) + storage key + read site
       (`<file>:<line>`).
     - Save-callback АЛЕ немає read-on-launch → **`ambiguous`**
       (orphan-код або half-implemented `final`).
     - Жоден callback не зберігає URL → **`tracker`** (apка
       щозапуску робить запит до бекенду; підтвердити через
       network-call як у п.1).

3. **`landing-mechanism = none`** → правило skip-ається, у шапці
   виводиться `link-storage = (n/a)`.

## Як виглядає поломка

«Поломка» як критична помилка тут неможлива (observation), але
варіант що привертає увагу — save без read-on-launch (orphan):

```kotlin
// WebView callback зберігає URL...
override fun onPageFinished(view: WebView?, url: String?) {
    prefs.edit().putString("last_url", url).apply()
}

// ...але жодне місце не читає "last_url" перед відкриттям WebView.
// Splash просто запускає WebView з hardcoded backend domain:
class SplashActivity : ComponentActivity() {
    override fun onCreate(s: Bundle?) {
        super.onCreate(s)
        webView.loadUrl("https://backend.example/?uuid=$uuid")  // ← ігнорує saved last_url
    }
}
```

## Як виглядає правильно

**Варіант `final`** (WebView, локальне збереження останньої URL):

```kotlin
class WebActivity : ComponentActivity() {
    override fun onCreate(s: Bundle?) {
        super.onCreate(s)
        val saved = prefs.getString("last_url", null)
        webView.loadUrl(saved ?: "https://backend.example/track/$uuid")

        webView.webViewClient = object : WebViewClient() {
            override fun doUpdateVisitHistory(view: WebView?, url: String?, isReload: Boolean) {
                url?.let { prefs.edit().putString("last_url", it).apply() }
            }
        }
    }
}
```

**Варіант `tracker`** (CustomTabs або WebView, бекенд резолвить):

```kotlin
class SplashActivity : ComponentActivity() {
    override fun onCreate(s: Bundle?) {
        super.onCreate(s)
        // Кожен запуск — той самий tracker URL. Бекенд виконує редірект.
        val intent = CustomTabsIntent.Builder().build()
        intent.launchUrl(this, Uri.parse("https://backend.example/track/$uuid"))
    }
}
```

## Як доповідати

**OBSERVATION** (tracker via CustomTabs):
```
[flow/link-storage-mechanism] OBSERVATION
  <file>:<line>   (CustomTabs entry point)
  Збереження landing-посилання: `tracker` (CustomTabs). CustomTabs не дозволяє перехопити URL із redirect-ланцюга, тому збереження серверне — апка щозапуску відкриває `<tracker URL or "(tracker URL through backend)">`.
  Як виправити: n/a — інформативний рядок для рецензента (також у шапці звіту як `link-storage`).
  Див.: rules/flow/link-storage-mechanism.md
```

**OBSERVATION** (final, WebView):
```
[flow/link-storage-mechanism] OBSERVATION
  <callback-file>:<line>   (callback, що зберігає URL)
  Збереження landing-посилання: `final` (WebView, `<callback-name>` → ключ `<storage-key>` у `<SharedPreferences|DataStore|Room|File>`). Наступний запуск читає збережену URL у `<read-file>:<line>` і відкриває її напряму, без бекенду.
  Як виправити: n/a — інформативний рядок для рецензента (також у шапці звіту як `link-storage`).
  Див.: rules/flow/link-storage-mechanism.md
```

**OBSERVATION** (tracker, WebView без save-callback):
```
[flow/link-storage-mechanism] OBSERVATION
  <webview-file>:<line>   (WebView entry point)
  Збереження landing-посилання: `tracker` (WebView без save-callback). Жоден з WebView callback-ів не зберігає URL у persistent storage — кожен запуск проходить redirect-ланцюжок з бекенду заново (запит до `<endpoint or "(не знайдено)">` з UUID).
  Як виправити: n/a — інформативний рядок для рецензента (також у шапці звіту як `link-storage`).
  Див.: rules/flow/link-storage-mechanism.md
```

**OBSERVATION** (ambiguous — orphan save):
```
[flow/link-storage-mechanism] OBSERVATION
  <callback-file>:<line>   (callback, що зберігає URL)
  Збереження landing-посилання: неоднозначно. WebView callback `<callback-name>` зберігає URL у `<storage-key>`, але жоден entry-point не читає цей ключ перед відкриттям WebView. Імовірно orphan-код або half-implemented `final`-стратегія.
  Як виправити: або реалізувати read-on-launch (читання `<storage-key>` у splash/launch flow), або видалити save-callback як мертвий код.
  Див.: rules/flow/link-storage-mechanism.md
```

## Виключення

Дозволено через `accepted-deviations` якщо команда не хоче бачити
цей пункт у звіті (наприклад, тестова апка без attribution flow, де
тип збереження не релевантний). Формат:
`flow/link-storage-mechanism: <reason>`. Обґрунтування обов'язкове.
