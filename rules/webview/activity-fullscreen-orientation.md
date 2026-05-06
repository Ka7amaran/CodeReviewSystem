---
id: webview/activity-fullscreen-orientation
severity: suspicious
category: webview
applies-to:
  - app/src/main/AndroidManifest.xml
  - app/src/main/java/**/*.kt
since: "2.0.0"
---

# Activity з WebView/CustomTabs: повноекранний + вільне обертання + видимий top bar

## Інваріант

Activity, що містить WebView або відкриває CustomTabs, має:
- **Вільне обертання** (без блокування orientation у portrait/landscape).
- **Повноекранний режим** без винятків.
- **Top status bar видимий завжди** (індикатори батареї, мережі —
  не приховані).
- Системні навігаційні кнопки — або статичні+видимі, або динамічні
  через свайп. Не блокувати.

## Як перевірити

1. Знайти Activity, що містить WebView (з §3.9 dataflow trace) або
   викликає `CustomTabsIntent.launchUrl(...)`.
2. У `AndroidManifest.xml` для цієї Activity:
   - Атрибут `android:screenOrientation` має бути або **відсутнім**,
     або одним із: `unspecified`, `fullSensor`, `user`,
     `userLandscape`, `userPortrait`, `sensorLandscape`,
     `sensorPortrait`. Не `portrait`/`landscape` (фіксована).
3. У коді Activity / Compose:
   - `WindowInsetsControllerCompat.systemBarsBehavior` НЕ має
     приховувати top status bar (тобто не
     `BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE` з прихованим
     `WindowInsetsCompat.Type.statusBars()`).
   - `setDecorFitsSystemWindows(false)` + `WindowInsetsControllerCompat`
     — OK для повноекранного UI, але statusBars() мають лишатись
     `show()`.
4. Кожне порушення — окремий finding `suspicious`.

### Що НЕ flag'ити

- **Runtime `requestedOrientation` setters у composable'ах**
  (`LocalActivity.current.requestedOrientation = ...` під час рендеру
  game-екрану як `PORTRAIT`, під час WebView-екрану як
  `UNSPECIFIED`) — це стандартний single-Activity Compose-патерн
  команди. Теоретичний "orientation lock leakage" коли юзер
  повертається з гри назад на WebView — НЕ є предметом цього
  правила, бо такий return-сценарій сам по собі заборонений
  (див. `flow/post-redirect-no-return`). Якщо back-stack правильно
  очищений після redirect, повернення на WebView неможливе → leakage
  неможливий.

## Як виглядає поломка

```xml
<activity
    android:name=".WebViewActivity"
    android:screenOrientation="portrait"               <!-- ❌ фіксована -->
    android:theme="@style/Theme.AppCompat.NoActionBar.Fullscreen" />
```

```kotlin
WindowInsetsControllerCompat(window, window.decorView).apply {
    hide(WindowInsetsCompat.Type.statusBars())          // ❌ прихований top bar
    systemBarsBehavior = BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
}
```

## Як виглядає правильно

```xml
<activity
    android:name=".WebViewActivity"
    android:screenOrientation="unspecified"             <!-- ✅ вільне обертання -->
    android:theme="@style/Theme.AppCompat.NoActionBar" />
```

```kotlin
WindowCompat.setDecorFitsSystemWindows(window, false)
WindowInsetsControllerCompat(window, window.decorView).apply {
    show(WindowInsetsCompat.Type.statusBars())          // ✅ top bar видимий
    systemBarsBehavior = BEHAVIOR_DEFAULT
}
```

## Як доповідати

```
[webview/activity-fullscreen-orientation] SUSPICIOUS
  <file>:<line>
  Activity з WebView/CustomTabs <має фіксовану orientation | приховує top status bar | блокує навігаційні кнопки>.
  Як виправити: <specific guidance>.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.8
```

## Виключення

Жодних для top status bar — він має бути видимим завжди (контракт
§3.8). Дозволено через `accepted-deviations` для фіксованої orientation,
якщо проєкт навмисно так налаштований (наприклад, специфічний layout
вимагає portrait). Обґрунтування обов'язкове.
