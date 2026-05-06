---
id: flow/post-redirect-no-return
severity: critical
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.4.0"
---

# Після redirect із Privacy Policy у гру повернутися назад неможливо

## Інваріант

Після успішного redirect із WebView (Privacy Policy / landing) у
гру, back-stack має бути **повністю очищений** так, щоб юзер не міг
повернутися на Privacy Policy через кнопку BACK / системний back-
gesture. Команда явно це не дозволяє: повторне відкриття Privacy
Policy робиться **тільки** через окрему кнопку з гри (наприклад,
у settings) — звичайна back-навігація не повинна вести назад на
landing.

Це critical-вимога: якщо back-stack залишає Privacy Policy маршрут
доступним, юзер може випадково повернутись туди і запустити
повторний redirect-flow, що ламає UX і attribution-метрики.

(Це правило застосовується лише якщо у проєкті виявлено
`landing-mechanism ∈ {webview, both}` за Stage 0.)

## Як перевірити

1. Знайти точку redirect-call (її вже знайшло
   `flow/redirect-method-correctness`): callback `onPostMessage` для
   7.1, `onConsoleMessage` для 7.2, `shouldOverrideUrlLoading` для 7.3.
2. У тілі цього callback'у простежити navigation call до game-екрану.
   Допустимі форми (одна з двох):

   **A. NavController з повним очищенням back-stack** (Jetpack
   Navigation Compose / Navigation Component):
   ```kotlin
   navController.navigate("game") {
       popUpTo(0)                              // ✅ очищує все
       // АБО:
       popUpTo(navController.graph.id) { inclusive = true }
       // АБО:
       popUpTo(navController.graph.startDestinationId) { inclusive = true }
   }
   ```

   **B. Cross-Activity з `finish()`** (multi-Activity архітектура):
   ```kotlin
   startActivity(Intent(this, GameActivity::class.java))
   finish()                                    // ✅ закриває WebView Activity
   // АБО:
   finishAffinity()
   ```

3. Поломка — ОДНЕ з:
   - `navController.navigate("game")` **без** `popUpTo(...)` блоку.
   - `popUpTo(...)` без `inclusive = true` (Privacy Policy маршрут
     залишається).
   - `popUpTo("ini")` (popUpTo з ID Privacy Policy маршруту, що
     залишає його у стеку — перевірити `inclusive` параметр).
   - `startActivity(Intent(...))` **без** наступного виклику
     `finish()` / `finishAffinity()` у тій самій функції.

4. Кожне порушення → finding `critical`.

## Як виглядає поломка

```kotlin
// 7.1 webMessageListener
override fun onPostMessage(...) {
    if (sourceOrigin.toString() != "https://domain.store") return
    if (message.data == "GO_GAME") {
        navController.navigate("game")          // ❌ без popUpTo
        // юзер може натиснути BACK і повернутись на Privacy Policy
    }
}
```

```kotlin
// 7.3 shouldOverrideUrlLoading
override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
    if (request.url.scheme == "app") {
        startActivity(Intent(context, GameActivity::class.java))  // ❌ без finish()
        return true
    }
    return false
}
```

## Як виглядає правильно

```kotlin
// NavController з повним очищенням
override fun onPostMessage(...) {
    if (sourceOrigin.toString() != "https://domain.store") return
    if (message.data == "GO_GAME") {
        navController.navigate("game") {
            popUpTo(navController.graph.id) { inclusive = true }  // ✅
        }
    }
}

// Cross-Activity з finish()
override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
    if (request.url.scheme == "app") {
        startActivity(Intent(context, GameActivity::class.java))
        finish()                                                   // ✅
        return true
    }
    return false
}
```

## Як доповідати

```
[flow/post-redirect-no-return] CRITICAL
  <file>:<line>   (точка navigation-call після redirect)
  Після redirect у гру back-stack не очищено: <`navigate(...)` без `popUpTo` | `popUpTo` без `inclusive = true` | `startActivity(...)` без `finish()`>. Юзер може натиснути BACK і повернутися на Privacy Policy.
  Як виправити: <для NavController: додайте блок `popUpTo(navController.graph.id) { inclusive = true }`> | <для cross-Activity: додайте `finish()` після `startActivity(...)`>.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.7
```

## Виключення

Дозволено через `accepted-deviations`, якщо у грі реалізовано
**окрему кнопку для повторного відкриття Privacy Policy**
(наприклад, у settings menu) — у такому випадку back-navigation з
гри на Privacy Policy маршрут є частиною свідомого UX. Обґрунтування
обов'язкове, із зазначенням де саме реалізовано repeat-open кнопку.
