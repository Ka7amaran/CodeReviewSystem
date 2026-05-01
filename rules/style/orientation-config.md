---
id: style/orientation-config
severity: warning
category: style
applies-to:
  - app/src/main/AndroidManifest.xml
  - app/src/main/java/**/*.kt
since: "1.5.0"
---

# Налаштування орієнтації екрану згідно бізнес-логіки

## Чому це важливо

Стандарт команди:
1. **У грі** — фіксована орієнтація (portrait або landscape) згідно
   з ігровим задумом. Це фіксується через
   `android:screenOrientation="portrait"` (або `"landscape"`,
   `"sensorLandscape"`) на ігровій Activity.
2. **У WebView/CustomTabs (policy/landing)** — обертання ВКЛЮЧЕНЕ
   (`"unspecified"` або `"fullSensor"`), бо OAuth-провайдери,
   платіжні форми, banking-flows часто оптимізовані для landscape
   на планшетах. Якщо WebView заблокована в portrait — користувач
   на планшеті бачить розірваний UI.

Помилки:
- Усі Activity заблоковані в portrait → планшет-юзери розчаровуються.
- Усі Activity без `screenOrientation` → гра вільно обертається,
  ламається UI.
- WebView активність наслідує portrait від game's Activity → flow
  шостого пункту страждає.

## Що перевірити

1. У `AndroidManifest.xml` знайти всі `<activity>` записи.
2. Для кожної Activity:
   - Якщо ім'я або `<intent-filter>` указують на гру (наприклад,
     `MainActivity` з LAUNCHER intent-filter, `GameActivity`,
     `PlayActivity`) — `android:screenOrientation` має бути
     встановлено (не `unspecified`).
   - Якщо ім'я указує на WebView/policy/auth (наприклад,
     `WebViewActivity`, `PolicyActivity`, `AuthActivity`,
     `LoginActivity`, `CheckoutActivity`) — `screenOrientation`
     має бути або відсутнім, або встановленим у `unspecified`,
     `fullSensor`, `user`, `userLandscape`, `userPortrait`,
     `sensorLandscape`, або `sensorPortrait`.
3. Спірні випадки (Activity без чіткого imeni) — flag з reason
   "perform manual review of orientation strategy".

## Як це виглядає у поганому проекті

```xml
<!-- AndroidManifest.xml -->
<activity
    android:name=".MainActivity"
    android:exported="true">
    <!-- screenOrientation відсутній — Activity вільно обертається,
         ігровий UI ламається при rotate -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>
</activity>

<activity
    android:name=".PolicyActivity"
    android:screenOrientation="portrait" />
<!-- ...але WebView з policy теж заблокована в portrait,
     planшет-користувачі розчаровуються при auth/payment -->
```

## Як це має виглядати

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:screenOrientation="portrait">  <!-- фіксована orientation для гри -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>
</activity>

<activity
    android:name=".PolicyActivity"
    android:screenOrientation="unspecified" />
<!-- WebView вільно обертається — OAuth/payment forms адекватно
     рендеряться на планшетах -->
```

## Як доповідати

```
[style/orientation-config] WARNING
  app/src/main/AndroidManifest.xml:<line>
  Activity "<activity-name>" <не має screenOrientation | має screenOrientation="<value>">, що не відповідає її ролі (гра потребує фіксованої, WebView/policy — вільної).
  Як виправити: <if game> "Додайте android:screenOrientation='portrait' (або 'landscape') на Activity згідно з задумом гри." </> <if webview> "Замініть android:screenOrientation на 'unspecified' або 'fullSensor', щоб WebView/policy вільно оберталась." </>.
  Див.: https://developer.android.com/guide/topics/manifest/activity-element#screen
```

## Виключення

Дозволено через `accepted-risks`, якщо Activity має нестандартну
роль (наприклад, splash з minimal UI, що однаково виглядає в обох
orientation'ах). Обґрунтування обов'язкове.
