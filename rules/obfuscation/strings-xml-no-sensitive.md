---
id: obfuscation/strings-xml-no-sensitive
severity: warning
category: obfuscation
applies-to:
  - app/src/main/res/values/strings.xml
  - app/src/main/res/values-*/strings.xml
since: "1.5.0"
---

# `strings.xml` не містить чутливих значень у відкритому вигляді

## Чому це важливо

`res/values/strings.xml` декомпілюється з APK без жодних додаткових
зусиль (`apktool` робить це за секунду). Декомпілятор бачить кожен
рядок, ім'я ресурсу, переклади.

Якщо в `strings.xml` лежать:
- URL'и сервера (`<string name="api_base_url">https://api.example.com</string>`)
- API-ключі (`<string name="onesignal_app_id">abc123-...</string>`)
- Attribution-параметри
- OAuth-client-id

— зловмисник отримує їх безкоштовно. Особливо неприпустимо для
URL'у бекенду — він має бути зашифрований і розшифровуватись у
runtime.

Стандарт команди: чутливі рядки — у `BuildConfig` (через
`buildConfigField` з `gradle.properties`) або зашифровані у Kotlin
з runtime-розшифруванням.

## Що перевірити

1. Прочитати `strings.xml`.
2. Для кожного `<string>` перевірити, чи його значення матчить хоч
   одну з sensitive-патернів:
   - URL: `https?://[^/]+\.(com|store|net|org|io|dev|app)`
   - API key (Base64-style): `[A-Za-z0-9+/_-]{32,}={0,2}`
   - OneSignal app id: UUID-format `[0-9a-f]{8}-[0-9a-f]{4}-...`
   - JWT-like: `eyJ[A-Za-z0-9_-]{10,}`
3. Виключення: рядки з name='app_name', 'menu_*', 'btn_*',
   'msg_*' — це user-facing text, навіть якщо містить URL (e.g.
   privacy-policy URL у `<string name="privacy_link">`). Тоді треба
   перевірити: чи це URL, що використовується runtime'ом, чи це
   текст для відображення.

   Я не можу повністю дисамбігувати без runtime-аналізу — flag усе
   match'ом і пропоную оператору вирішити (через `accepted-risks`).
4. Кожен match = окрема знахідка.

## Як це виглядає у поганому проекті

```xml
<!-- res/values/strings.xml -->
<resources>
    <string name="app_name">My App</string>
    <string name="api_base_url">https://api.example.com</string>
    <string name="onesignal_app_id">abc12345-6789-abcd-ef01-23456789abcd</string>
    <string name="ads_id_secret">aBcDeFgHiJkLmNoPqRsTuVwXyZ012345</string>
</resources>
```

## Як це має виглядати

`strings.xml` — тільки user-facing рядки. Чутливі — у `BuildConfig`
з `gradle.properties`:

```kotlin
// app/build.gradle.kts
defaultConfig {
    val onesignalId = providers.gradleProperty("onesignal.id").get()
    buildConfigField("String", "ONESIGNAL_APP_ID", "\"$onesignalId\"")
}
```

```properties
# gradle.properties (НЕ комітиться у Git)
onesignal.id=abc12345-6789-abcd-ef01-23456789abcd
```

```kotlin
// runtime
OneSignal.initWithContext(context, BuildConfig.ONESIGNAL_APP_ID)
```

## Як доповідати

```
[obfuscation/strings-xml-no-sensitive] WARNING
  app/src/main/res/values/strings.xml:<line>
  Рядок "<string-name>" містить значення, що схоже на <URL|API-key|OneSignal-app-id|JWT>: <first-20-chars>...
  Як виправити: винести у BuildConfig field з gradle.properties (для public-private split) або зашифрувати з runtime-decrypt'ом (як це зроблено для зашифрованих endpoint'ів). strings.xml декомпілюється з APK тривіально.
  Див.: https://developer.android.com/studio/build/build-variants#configure-build
```

## Виключення

Дозволено через `accepted-risks`, якщо рядок справді user-facing
(privacy policy link, contact email) і призначений для показу,
не runtime-API. Обґрунтування обов'язкове — поясніть, де цей
рядок використовується.
