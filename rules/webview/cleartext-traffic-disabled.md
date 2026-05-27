---
id: webview/cleartext-traffic-disabled
severity: critical
category: webview
applies-to:
  - app/src/main/AndroidManifest.xml
  - app/src/main/res/xml/*.xml
since: "2.8.0"
---

# Cleartext-трафік у Manifest заборонений (для WebView / CustomTabs)

## Інваріант

Атрибут `android:usesCleartextTraffic` на елементі `<application>` у
`app/src/main/AndroidManifest.xml` **не може мати значення `"true"`**.
Допустимі стани:
- атрибут **відсутній** і `targetSdkVersion >= 28` (дефолт OS = false);
- атрибут явно `"false"`.

Інваріант існує тому, що апки використовують **WebView і/або CustomTabs**
як основну поверхню контенту — `true` означає, що будь-який HTTP
(не-HTTPS) URL, відкритий у WebView/CustomTabs/HTTP-клієнті апки,
передаватиметься у відкритому вигляді.

NSC (`networkSecurityConfig`) з `cleartextTrafficPermitted="true"` може
обходити manifest-заборону — це емітимо як `OBSERVATION`, рішення
легітимності залишаємо за людиною.

## Як перевірити

Це **manifest-перевірка з опціональним walk-у NSC**, а не grep по проєкту.

1. Прочитати `app/src/main/AndroidManifest.xml`.
2. Знайти елемент `<application ...>` (типово один).
3. Витягти `targetSdkVersion`: з `defaultConfig.targetSdk` у
   `app/build.gradle(.kts)` (це source of truth — gradle overrides
   manifest). Якщо в gradle не задано — взяти з `<uses-sdk
   android:targetSdkVersion="..."/>` у маніфесті. Якщо ніде не задано —
   вважати `targetSdk = 1` (worst case).
4. Перевірити `android:usesCleartextTraffic`:
   - `"true"` → finding `CRITICAL`.
   - `"false"` → інваріант виконано (Перевірені інваріанти).
   - **відсутній** + `targetSdk >= 28` → інваріант виконано.
   - **відсутній** + `targetSdk < 28` → finding `CRITICAL` (історичний
     дефолт OS = true).
5. Незалежно від п.4, якщо `<application>` має
   `android:networkSecurityConfig="@xml/<name>"`:
   - відкрити `app/src/main/res/xml/<name>.xml`;
   - якщо референс битий (файл відсутній) → emit `OBSERVATION`
     («NSC файл `@xml/<name>` не знайдено»);
   - `<base-config cleartextTrafficPermitted="true">` → emit
     `OBSERVATION` («NSC дозволяє cleartext глобально — обходить
     manifest-заборону»);
   - `<domain-config cleartextTrafficPermitted="true">` → emit
     `OBSERVATION` («NSC дозволяє cleartext для конкретних доменів —
     перевірте навмисність»).
6. Перевіряється лише `app/src/main/AndroidManifest.xml`.
   `debug/AndroidManifest.xml` ігнорується (легітимний debug-overlay).

## Як виглядає поломка

```xml
<!-- app/src/main/AndroidManifest.xml -->
<application
    android:usesCleartextTraffic="true"
    android:label="@string/app_name"
    ...>
    <!-- WebView/CustomTabs усередині пропускатимуть http:// у відкритому вигляді -->
</application>
```

Або через NSC (емітимо як OBSERVATION):

```xml
<!-- app/src/main/res/xml/network_security_config.xml -->
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
```

## Як виглядає правильно

Варіант А — явно `false`:

```xml
<application
    android:usesCleartextTraffic="false"
    ...>
```

Варіант Б — атрибут відсутній (рекомендовано для `targetSdk >= 28`, бо дефолт OS = `false`; для старих targetSdk потрібен явний Варіант А):

```xml
<application
    android:label="@string/app_name"
    ...>
```

## Як доповідати

Manifest-варіант:

```
[webview/cleartext-traffic-disabled] CRITICAL
  app/src/main/AndroidManifest.xml:<line>
  <application android:usesCleartextTraffic="true"> — апка явно дозволяє HTTP-трафік. WebView/CustomTabs/HTTP-клієнти можуть відкривати http:// URL у відкритому вигляді, що є витоком даних.
  Як виправити: видаліть атрибут (на API 28+ дефолт = false) або явно поставте android:usesCleartextTraffic="false".
  Див.: rules/webview/cleartext-traffic-disabled.md
```

Manifest-варіант (відсутній атрибут + старий targetSdk):

```
[webview/cleartext-traffic-disabled] CRITICAL
  app/src/main/AndroidManifest.xml:<line of <application> element>
  android:usesCleartextTraffic відсутній, але targetSdkVersion = <N> (< 28) — історичний дефолт OS = true, cleartext фактично дозволено.
  Як виправити: явно додайте android:usesCleartextTraffic="false" у <application>, або підніміть targetSdk до 28+.
  Див.: rules/webview/cleartext-traffic-disabled.md
```

NSC-варіант (base-config — глобально):

```
[webview/cleartext-traffic-disabled] OBSERVATION
  app/src/main/res/xml/<nsc-file>.xml:<line>
  NSC <base-config cleartextTrafficPermitted="true"> — дозволяє cleartext глобально, обходить manifest-заборону для всього трафіку апки.
  Як виправити: переконайтеся, що дозвіл навмисний (legacy backend без TLS, локальний сервер); інакше — заберіть атрибут із NSC.
  Див.: rules/webview/cleartext-traffic-disabled.md
```

NSC-варіант (domain-config — для конкретних доменів):

```
[webview/cleartext-traffic-disabled] OBSERVATION
  app/src/main/res/xml/<nsc-file>.xml:<line>
  NSC <domain-config cleartextTrafficPermitted="true"> — дозволяє cleartext для перелічених доменів, обходить manifest-заборону. Перевірте, чи це навмисно і чи домени не зачіпають WebView/CustomTabs.
  Як виправити: якщо дозвіл випадковий — заберіть атрибут; якщо навмисний — задокументуйте у accepted-deviations.
  Див.: rules/webview/cleartext-traffic-disabled.md
```

## Виключення

Допускається через `accepted-deviations` у `.claude/CLAUDE.md` з reason.
Легітимні причини: інтеграція з legacy-бекендом, який ще не на TLS;
локальний dev-сервер, доступний тільки в debug-зборці. Рекомендоване
обхідне рішення — винести cleartext-дозвіл у `debug/AndroidManifest.xml`-overlay,
тоді release-маніфест чистий і exception не потрібен.
