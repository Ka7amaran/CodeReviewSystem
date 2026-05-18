---
id: flow/post-redirect-no-return
severity: critical
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.4.0"
---

# Privacy Policy маршрут недоступний через back-навігацію після redirect

## Інваріант

Після успішного redirect із WebView (Privacy Policy / landing) у гру,
**Privacy Policy маршрут повинен стати недосяжним через кнопку BACK /
системний back-gesture**. Юзер не може випадково повернутися на
landing через звичайну back-навігацію — повторне відкриття Privacy
Policy робиться **тільки** через окрему кнопку з гри (наприклад, у
settings menu).

Це end-state contract: який саме механізм використано для очищення
back-stack — рішення команди. Важлива поведінка, а не реалізація.

Це critical-вимога: якщо Privacy Policy маршрут лишається досяжним,
юзер може випадково запустити повторний redirect-flow, що ламає UX і
attribution-метрики.

(Це правило застосовується лише якщо у проєкті виявлено
`landing-mechanism ∈ {webview, both}` за Stage 0.)

## Каталог відомих патернів

Список механізмів очищення back-stack, які команда вже використовувала.
**Extensible catalog, не closed list** — новий механізм, що задовольняє
інваріант, surfaces як `OBSERVATION` для додавання сюди.

**A. NavController з повним очищенням back-stack** (Jetpack Navigation
Compose / Navigation Component):
```kotlin
navController.navigate("game") {
    popUpTo(0)                                       // ✅ очищує все
    // АБО:
    popUpTo(navController.graph.id) { inclusive = true }
    // АБО:
    popUpTo(navController.graph.startDestinationId) { inclusive = true }
}
```

**B. Cross-Activity з `finish()` / `finishAffinity()`** (multi-Activity
архітектура):
```kotlin
startActivity(Intent(this, GameActivity::class.java))
finish()                                             // ✅ закриває WebView Activity
// АБО:
finishAffinity()                                     // ✅ закриває всю task chain
```

Якщо команда винайшла C, D... (наприклад, Fragment back-stack reset
через `supportFragmentManager.popBackStack(..., POP_BACK_STACK_INCLUSIVE)`,
або `Activity.recreate()` після очищення NavGraph) — додайте сюди
після того, як OBSERVATION підкаже патерн.

## Як перевірити

1. Знайти точку redirect-call (її вже знайшло
   `flow/redirect-method-correctness`): catalog-pattern (7.1-7.5) або
   novel mechanism — будь-який callback, тіло якого досягає in-app
   навігації.
2. У тілі цього callback'у простежити navigation call до game-екрану.
3. Перевірити, що back-stack після цього виклику **не містить
   Privacy Policy маршрут**. Класифікація:
   - **Catalog pattern A (NavController + popUpTo inclusive)** — pass.
   - **Catalog pattern B (startActivity + finish/finishAffinity у тій
     самій функції)** — pass.
   - **Novel mechanism**, що реально очищає back-stack так, що Privacy
     Policy недоступна (визначається dataflow-аналізом back-stack
     mutations) → `OBSERVATION` "знайдено новий патерн очищення
     back-stack — додайте до каталогу".
   - **Поломка** — back-stack після redirect МІСТИТЬ Privacy Policy
     маршрут (BACK поверне юзера). Типові форми:
     - `navController.navigate("game")` **без** `popUpTo(...)` блоку.
     - `popUpTo(...)` без `inclusive = true` (Privacy Policy маршрут
       залишається).
     - `popUpTo("<privacy-route-id>")` без `inclusive = true`.
     - `startActivity(Intent(...))` **без** `finish()` /
       `finishAffinity()` у тій самій функції.
     → `CRITICAL`.

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

**CRITICAL** (back-stack лишає Privacy Policy досяжним):
```
[flow/post-redirect-no-return] CRITICAL
  <file>:<line>   (точка navigation-call після redirect)
  Після redirect у гру back-stack не очищено: <`navigate(...)` без `popUpTo` | `popUpTo` без `inclusive = true` | `startActivity(...)` без `finish()` | novel mechanism, що не виконує очищення>. Юзер може натиснути BACK і повернутися на Privacy Policy.
  Як виправити: використайте catalog pattern A (`navController.navigate("game") { popUpTo(navController.graph.id) { inclusive = true } }`) АБО B (`startActivity(...)` + `finish()`) АБО свій механізм, що дійсно робить Privacy Policy маршрут недосяжним.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.7
```

**OBSERVATION** (novel mechanism очищає back-stack правильно):
```
[flow/post-redirect-no-return] OBSERVATION
  <file>:<line>
  Знайдено новий патерн очищення back-stack: `<mechanism-name>` (поза каталогом A/B). Інваріант виконується — Privacy Policy маршрут недосяжний через back-navigation. Якщо це свідомий team-патерн, додайте у каталог відомих механізмів у `rules/flow/post-redirect-no-return.md §Каталог відомих патернів`.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.7
```

## Виключення

Дозволено через `accepted-deviations`, якщо у грі реалізовано
**окрему кнопку для повторного відкриття Privacy Policy**
(наприклад, у settings menu) — у такому випадку back-navigation з
гри на Privacy Policy маршрут є частиною свідомого UX. Обґрунтування
обов'язкове, із зазначенням де саме реалізовано repeat-open кнопку.
