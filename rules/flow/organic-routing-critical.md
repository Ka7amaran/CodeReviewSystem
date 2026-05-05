---
id: flow/organic-routing-critical
severity: critical
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
requires-project-type: with-attribution
---

# Organic-користувач теж відкриває WebView/CustomTabs

## Інваріант

Для **всіх** користувачів (organic AND non-organic):
- Запит на бекенд-домен виконується.
- UUID передається.
- WebView/CustomTabs відкривається.

Для **тільки non-organic**:
- Виконується POST з `{uuid, ref, adId}`.

Organic визначається за referrer'ом, що містить
`utm_source=google-play&utm_medium=organic`.

**Якщо organic-користувач йде одразу в гру, минаючи WebView — це
КРИТИЧНИЙ БАГ.** Це найважливіший інваріант плагіна.

## Як перевірити

1. Знайти точку, де читається referrer (з §3.4 spec'у — будь-який
   спосіб отримання Install Referrer).
2. Знайти умовний branch після того, як referrer прочитаний —
   `if (ref.contains("utm_medium=organic"))` або еквівалент.
3. **Перевірити дві гілки:**
   - **Branch для organic** має призводити до запуску WebView/CustomTabs
     (виклик `webView.loadUrl(...)`, `CustomTabsIntent.launchUrl(...)`,
     навігація на WebView-екран). Якщо ця гілка призводить до
     навігації на гру (Game-екран, без проходження WebView) →
     **CRITICAL FINDING**.
   - **Branch для non-organic** має містити POST-виклик до
     backend-домену з тілом `{uuid, ref, adId}` АБО переадресацію
     на WebView (POST може бути перед WebView). Якщо POST
     відсутній — це теж critical, але це покривається окремим
     правилом `flow/non-organic-post-required`.
4. Якщо умовний branch взагалі відсутній (нема перевірки на
   organic) і апка просто завжди йде в гру → CRITICAL.

Це найскладніша dataflow-перевірка плагіна. Агент має простежити
повну стартову послідовність і знайти **рішення routing'а**, а не
просто наявність окремих викликів.

## Як виглядає поломка

```kotlin
class StartupRouter {
    suspend fun decide(): Route {
        val ref = referrerClient.fetch()
        return if (ref.contains("utm_medium=organic")) {
            Route.Game            // ❌ КРИТИЧНИЙ БАГ — organic минає WebView
        } else {
            Route.WebView(uuid)
        }
    }
}
```

## Як виглядає правильно

```kotlin
class StartupRouter {
    suspend fun decide(): Route {
        val ref = referrerClient.fetch()
        val isOrganic = ref.contains("utm_source=google-play&utm_medium=organic")
        if (!isOrganic) {
            backend.post(uuid, ref, adId)   // POST тільки для non-organic
        }
        return Route.WebView(uuid)           // ✅ WebView для всіх
    }
}
```

## Як доповідати

```
[flow/organic-routing-critical] CRITICAL
  <file>:<line>   (точка routing-рішення)
  Organic-користувачі направляються одразу в гру, минаючи WebView/CustomTabs. Це порушує контракт §3.6 (WebView відкривається для всіх користувачів незалежно від organic-статусу).
  Як виправити: WebView/CustomTabs має відкриватися безумовно для всіх. Єдина різниця для non-organic — додатковий POST на бекенд-домен з `{uuid, ref, adId}` ПЕРЕД відкриттям WebView (або паралельно).
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.6
```

## Виключення

Жодних. Це визначальний контракт продукту — без виконання цього
інваріанту бізнес-метрики attribution руйнуються. Не вимикається
через `accepted-deviations`.
