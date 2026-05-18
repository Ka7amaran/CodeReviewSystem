---
id: webview/config-completeness
severity: suspicious
category: webview
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
  - app/src/main/AndroidManifest.xml
since: "2.0.0"
---

# WebView має базові налаштування + use-case-залежні

## Інваріант

Якщо у проєкті виявлено хоча б один WebView-instance (Stage 0
detection: `landing-mechanism ∈ {webview, both}`), кожен такий
WebView-instance має **функціонально працювати** для типової
landing-сторінки команди (Privacy Policy + потенційні OAuth логіни,
file upload, permission requests за наявності відповідного use-case'у
у manifest).

Інваріант — *WebView функціонує*, не *WebView має точно ці APIs
викликані*. Якщо команда винайшла альтернативний механізм досягнення
тієї ж функціональності (наприклад, custom WebView subclass, що
встановлює налаштування у конструкторі замість через `settings.apply`,
або Compose-wrapper з власним config layer) — це OBSERVATION
("новий механізм налаштування — додайте у каталог"), не CRITICAL.

Якщо WebView у коді немає взагалі (`landing-mechanism ∈ {custom-tabs,
none}`) — правило skip'ається.

### Каталог відомих налаштувань — базовий набір

- `mixedContentMode = 0` (≡ `WebSettings.MIXED_CONTENT_ALWAYS_ALLOW`) —
  команда canonical preset вимагає саме `0`. Це свідомий вибір
  (deals with legacy http-ресурсами на landing-сторінках). Якщо
  значення `0` (або `MIXED_CONTENT_ALWAYS_ALLOW` константа) — pass
  silently. Якщо значення `1` (`NEVER_ALLOW`) або `2`
  (`COMPATIBILITY_MODE`) — finding `suspicious` "значення X
  відрізняється від canonical 0". Якщо взагалі не встановлено
  (залишається API default = 1) — finding `suspicious` "не
  встановлено явно".
- `javaScriptEnabled = true` — будь-який сучасний веб без JS не працює.
- `domStorageEnabled = true` — багато сайтів вимагають localStorage.
- `webViewClient` встановлений — інакше будь-який redirect відкриває
  зовнішній браузер.
- `webChromeClient` встановлений — потрібен для permission/upload/console
  callback'ів.
- `CookieManager.getInstance().setAcceptCookie(true)` +
  `setAcceptThirdPartyCookies(webView, true)` — інакше ламається
  OAuth (Google/Facebook/Apple sign-in) у WebView.

### Каталог відомих налаштувань — use-case-залежні (вимагаються лише при відповідних доказах у manifest)

- `onShowFileChooser` (override у `WebChromeClient`) — flag missing
  **тільки якщо** `AndroidManifest.xml` оголошує `CAMERA`
  АБО `READ_MEDIA_IMAGES` (Android 13+) АБО `READ_EXTERNAL_STORAGE`.
  Це означає що проєкт реально дозволяє upload фото/файлів через
  WebView.
- `onPermissionRequest` (override у `WebChromeClient`) — flag missing
  **тільки якщо** `AndroidManifest.xml` оголошує `CAMERA`
  АБО `RECORD_AUDIO`. Без цього override веб-сторінка не зможе
  отримати дозвіл на камеру/мікрофон через WebView.

### Виключені з правила (не flag'аються — або не детектуються з
Android-боку, або переїхали в інше правило)

- `setDownloadListener` — потрібний лише якщо у Privacy Policy /
  landing-page реально є download-flow (PDF, APK-update). Це залежить
  від HTML на бекенді — Android-кодом не детектується. Якщо команда
  має такий flow — це responsibility QA test'у, не статичного аналізу.
- `onShowCustomView` — потрібний лише для HTML5 fullscreen video.
  Залежить від HTML.
- `setSupportMultipleWindows(true)` — потрібний лише якщо HTML
  використовує `target="_blank"` / `window.open(...)`. Залежить від HTML.
- `cacheMode = LOAD_DEFAULT`, `setLayerType(LAYER_TYPE_HARDWARE, null)`,
  `setLayerType` cleanup — це performance-related, перевіряються
  у `perf/webview-pitfalls` як observation.
- `loadsImagesAutomatically`, `useWideViewPort`, `loadWithOverviewMode`,
  `allowFileAccess`, `allowContentAccess`, `builtInZoomControls`,
  `displayZoomControls`, `javaScriptCanOpenWindowsAutomatically`,
  `databaseEnabled`, `importantForAutofill` — UX-вибір команди / default
  values / deprecated. Не flag'аються.

## Як перевірити

1. Stage 0 надає `landing-mechanism`. Якщо не `webview` і не `both` —
   skip.
2. Знайти кожне створення WebView-instance: `WebView(context)`,
   `findViewById<WebView>(...)`, `AndroidView { factory = { WebView(it) } }`.
3. Для кожного WebView у тому самому файлі/функції/builder'і
   перевірити **базовий набір** (6 пунктів вище). Кожна відсутня —
   окремий finding `suspicious`.
4. Прочитати `app/src/main/AndroidManifest.xml`. Запам'ятати які з
   permission'ів оголошено: `CAMERA`, `RECORD_AUDIO`, `READ_MEDIA_IMAGES`,
   `READ_EXTERNAL_STORAGE`.
5. Для use-case-залежних:
   - Якщо у manifest є `CAMERA` АБО `READ_MEDIA_IMAGES` АБО
     `READ_EXTERNAL_STORAGE`, але `WebChromeClient` не override'ить
     `onShowFileChooser` → finding `suspicious`. Reason: проект
     декларує файлові permission'и, але WebView їх не використовує —
     ймовірно зламаний upload-flow.
   - Якщо у manifest є `CAMERA` АБО `RECORD_AUDIO`, але
     `WebChromeClient` не override'ить `onPermissionRequest` →
     finding `suspicious`. Reason: WebView не зможе попросити дозвіл
     на камеру/мікрофон у веб-сторінки.
6. Все інше з v2.0/v2.1 preset'у НЕ flag'ається.
7. **Novel mechanism**: якщо WebView функціонально працює, але
   налаштування виставлені через нестандартний механізм (custom
   WebView subclass, Compose config-wrapper, factory-based pattern,
   тощо), і всі необхідні invariants задовольняються — emit
   `OBSERVATION` "знайдено новий механізм конфігурації WebView:
   `<name>`; функціональні інваріанти задовольняються; додайте у
   каталог якщо team-pattern". Не emit suspicious.

## Як виглядає поломка

```kotlin
// AndroidManifest.xml має <uses-permission android:name="android.permission.CAMERA"/>
val webView = WebView(context)
webView.loadUrl(url)
// ❌ нічого не налаштовано — нема навіть JS, cookies, webViewClient
// ❌ є camera permission у manifest, але onShowFileChooser/onPermissionRequest відсутні
```

## Як виглядає правильно

```kotlin
val webView = WebView(context).apply {
    CookieManager.getInstance().setAcceptCookie(true)
    CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
    settings.apply {
        mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        javaScriptEnabled = true
        domStorageEnabled = true
    }
    webViewClient = myWebClient
    webChromeClient = object : WebChromeClient() {
        // якщо у manifest є CAMERA / READ_MEDIA_IMAGES / READ_EXTERNAL_STORAGE:
        override fun onShowFileChooser(...): Boolean { /* ... */ }
        // якщо у manifest є CAMERA / RECORD_AUDIO:
        override fun onPermissionRequest(request: PermissionRequest) { /* ... */ }
    }
}
```

## Як доповідати

```
[webview/config-completeness] SUSPICIOUS
  <file>:<line>
  WebView не має <core: javaScriptEnabled | domStorageEnabled | mixedContentMode = 0 | webViewClient | webChromeClient | setAcceptThirdPartyCookies>
  | (manifest декларує <CAMERA | READ_MEDIA_IMAGES | READ_EXTERNAL_STORAGE>) WebChromeClient не override'ить `onShowFileChooser` — upload-flow зламаний
  | (manifest декларує <CAMERA | RECORD_AUDIO>) WebChromeClient не override'ить `onPermissionRequest` — WebView не зможе попросити дозвіл.
  Як виправити: <specific setting line for the missing item>.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.9
```

## Виключення

Дозволено через `accepted-deviations`, якщо WebView читає виключно
read-only сторінку без auth/cookies/upload (рідкісний випадок —
наприклад, статична HTML-сторінка-документ). Обґрунтування
обов'язкове — поясніть, який саме flow обмежений.
