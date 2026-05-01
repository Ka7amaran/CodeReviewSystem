---
id: style/webview-config-completeness
severity: warning
category: style
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "1.5.0"
---

# Повна конфігурація WebView для policy/landing flow

## Чому це важливо

WebView у нашому flow — це не просто браузер для статичної сторінки.
Він має підтримати: авторизацію (Google/Facebook/Apple OAuth),
платіжні потоки, file upload з камери та галереї, відео у
повноекранному режимі, third-party cookies, redirect-навігацію за
deep links.

Якщо хоч один із пунктів пропустити — користувач застрягне на
порожньому екрані під час auth/payment, або не зможе завантажити
аватар/документ. Це безпосередньо ламає flow онбордингу.

Стандартний `WebView()` без явної конфігурації — це bug. Налаштувати
все треба явно.

## Що перевірити

Знайти кожен файл, що містить `WebView` instantiation
(`WebView(context)` або `findViewById<WebView>(...)` або
`AndroidView { factory = { WebView(it) } }`).

Для кожного такого WebView перевірити, що в межах того ж файлу/класу
налаштовані:

1. `webView.settings.javaScriptEnabled = true`
2. `webView.settings.domStorageEnabled = true`
3. `webView.settings.databaseEnabled = true`
4. `CookieManager.getInstance().setAcceptCookie(true)` AND
   `CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)`
5. `WebChromeClient` overridden with `onShowFileChooser` (для
   `<input type="file">`) AND `onPermissionRequest` (для камери).
6. `WebChromeClient.onShowCustomView` / `onHideCustomView` (для
   повноекранного відео).
7. `webView.setDownloadListener { ... }` (для прямого download'у).
8. `WebViewClient` overridden with `shouldOverrideUrlLoading` (для
   deep-link перехоплення та `target="_blank"`).
9. Підтримка історії: `webView.canGoBack()` + `webView.goBack()` у
   back-press handler.

Кожна відсутня налаштування = окрема знахідка для того WebView.

## Як це виглядає у поганому проекті

```kotlin
val webView = WebView(context)
webView.loadUrl(url)
// все, ніяких settings, cookies, file chooser, тощо
```

## Як це має виглядати

```kotlin
val webView = WebView(context).apply {
    settings.apply {
        javaScriptEnabled = true
        domStorageEnabled = true
        databaseEnabled = true
        allowFileAccess = true
        mediaPlaybackRequiresUserGesture = false
    }
    CookieManager.getInstance().apply {
        setAcceptCookie(true)
        setAcceptThirdPartyCookies(this@apply, true)
    }
    webChromeClient = object : WebChromeClient() {
        override fun onShowFileChooser(...) { ... }
        override fun onPermissionRequest(...) { ... }
        override fun onShowCustomView(...) { ... }
        override fun onHideCustomView() { ... }
    }
    webViewClient = object : WebViewClient() {
        override fun shouldOverrideUrlLoading(...) { ... }
    }
    setDownloadListener { url, _, _, _, _ -> ... }
}
```

## Як доповідати

```
[style/webview-config-completeness] WARNING
  <file>:<line>
  WebView у <file> не має налаштування "<missing-config>" — flow онбордингу/auth/upload буде зламано.
  Як виправити: <specific suggestion based on missing config, e.g. "Додайте `webView.settings.javaScriptEnabled = true` після створення WebView" або "Додайте override onShowFileChooser у WebChromeClient">.
  Див.: https://developer.android.com/develop/ui/views/layout/webapps/webview
```

## Виключення

Дозволено через `accepted-risks`, якщо WebView використовується для
read-only-сторінки без auth/upload/video (рідкісний випадок).
Обґрунтування обов'язкове — поясніть, який саме flow обмежений.
