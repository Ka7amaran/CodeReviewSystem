---
id: webview/config-completeness
severity: suspicious
category: webview
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
---

# WebView має повний канонічний preset налаштувань

## Інваріант

Якщо у проєкті використовується WebView (`landing-mechanism = webview`),
кожен WebView-instance має містити канонічний preset налаштувань
команди (§3.9 spec'у):

- `mixedContentMode = 0`
- `javaScriptEnabled = true`
- `domStorageEnabled = true`
- `databaseEnabled = true`
- `loadsImagesAutomatically = true`
- `useWideViewPort = true`
- `allowFileAccess = true`
- `javaScriptCanOpenWindowsAutomatically = true`
- `loadWithOverviewMode = true`
- `allowContentAccess = true`
- `setSupportMultipleWindows(true)`
- `builtInZoomControls = true` + `displayZoomControls = false`
- `cacheMode = LOAD_DEFAULT`
- `setLayerType(LAYER_TYPE_HARDWARE, null)`
- `importantForAutofill = IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS` (API 26+)
- `CookieManager.setAcceptCookie(true)` + `setAcceptThirdPartyCookies(webView, true)`
- `webViewClient` встановлений
- `webChromeClient` встановлений (з `onShowFileChooser`,
  `onPermissionRequest`, `onShowCustomView`, `onConsoleMessage` за
  потребою)
- `setDownloadListener` встановлений

## Як перевірити

1. Знайти кожне створення WebView-instance: `WebView(context)`,
   `findViewById<WebView>(...)`, `AndroidView { factory = { WebView(it) } }`.
2. Для кожного WebView у тому самому файлі/функції перевірити
   присутність всіх settings із preset'у.
3. Кожна відсутня налаштування — окремий finding `suspicious`.
4. Опціональні налаштування (Google Sign-In support, deep-link
   handling для Telegram/Instagram/TikTok) — НЕ flag, але якщо
   присутні і виглядають зламаними (наприклад, regex для deep-link
   очевидно неправильний) — `observation`.

## Як виглядає поломка

```kotlin
val webView = WebView(context)
webView.loadUrl(url)
// ❌ нічого не налаштовано
```

## Як виглядає правильно

```kotlin
val webView = WebView(context).apply {
    layoutParams = LayoutParams(MATCH_PARENT, MATCH_PARENT)
    CookieManager.getInstance().setAcceptCookie(true)
    CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
    isSaveEnabled = true
    isFocusable = true
    isFocusableInTouchMode = true
    setLayerType(LAYER_TYPE_HARDWARE, null)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        importantForAutofill = IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
    }
    settings.apply {
        mixedContentMode = 0
        javaScriptEnabled = true
        domStorageEnabled = true
        databaseEnabled = true
        loadsImagesAutomatically = true
        useWideViewPort = true
        allowFileAccess = true
        javaScriptCanOpenWindowsAutomatically = true
        loadWithOverviewMode = true
        allowContentAccess = true
        setSupportMultipleWindows(true)
        builtInZoomControls = true
        displayZoomControls = false
        cacheMode = WebSettings.LOAD_DEFAULT
    }
    webViewClient = myWebClient
    webChromeClient = myChromeClient
    setDownloadListener { url, _, _, _, _ -> startDownload(url) }
}
```

## Як доповідати

```
[webview/config-completeness] SUSPICIOUS
  <file>:<line>
  WebView не має налаштування "<missing-setting>" — це може зламати <auth flow | file upload | fullscreen video | cookies | deep-link>.
  Як виправити: додайте `<specific setting line>` у блок налаштування WebView.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.9
```

## Виключення

Дозволено через `accepted-deviations`, якщо WebView читає виключно
read-only сторінку без auth/upload/cookies (рідкісний випадок).
Обґрунтування обов'язкове — поясніть, який саме flow обмежений.
