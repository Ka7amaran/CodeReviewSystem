---
id: security/splash-attribution-flow
severity: warning
category: security
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "1.5.0"
---

# Повний attribution-flow на splash-скрін

## Чому це важливо

Стандартний бізнес-flow команди при першому запуску додатку:

1. Перевірити локальне сховище на наявність UUID
   (Long13/Long19/SHA-1/SHA-256 формати).
2. Якщо UUID немає (перший запуск):
   a. Згенерувати кастомний UUID, зберегти в (Encrypted)SharedPreferences.
   b. Ініціалізувати OneSignal: `OneSignal.initWithContext(...)` +
      `OneSignal.login(uuid)`.
   c. Отримати install referrer через `InstallReferrerClient`.
   d. Якщо referrer НЕ містить
      `utm_source=google-play&utm_medium=organic` → отримати adId
      через `play-services-ads-identifier`.
   e. POST-запит на сервер із `uuid`, `ref`, `adId`.
   f. Завантажити WebView/CustomTabs за URL з UUID.
3. Якщо UUID є → одразу WebView без повторної ініціалізації.

Якщо хоч один із кроків відсутній — attribution невидимий, бекенд
не може правильно класифікувати трафік, бізнес-метрики ламаються.

## Що перевірити

Знайти splash-related файл (тригер: ім'я містить `Splash` AND клас
розширює `ViewModel` або `ComponentActivity`, або файл лежить у
`feature/splash/` чи аналогічно). Для нього перевірити присутність:

1. UUID-перевірка: `getString("uuid"...)` АБО `getString("user_id"...)`
   на старті.
2. UUID-генерація fallback: `UUID.randomUUID()` АБО `SecureRandom`-based.
3. OneSignal init: `OneSignal.initWithContext(` АБО `OneSignal.Default.initWithContext(`.
4. OneSignal login: `OneSignal.login(` АБО еквівалент.
5. Install Referrer: `InstallReferrerClient.newBuilder(` АБО
   `installReferrerClient`.
6. Ads Identifier: `AdvertisingIdClient.getAdvertisingIdInfo(` АБО
   еквівалент.
7. POST request: HTTP-клієнт post-метод (Ktor `client.post(`, OkHttp
   `Request.Builder().post(`, тощо), що звертається до
   зовнішнього сервера (НЕ localhost).

Кожен пропущений крок = окрема знахідка.

## Як це виглядає у поганому проекті

```kotlin
class SplashViewModel : ViewModel() {
    fun start() {
        // одразу navigate(Game)
        _state.value = SplashState.Done
    }
}
```

## Як це має виглядати

```kotlin
class SplashViewModel(
    private val prefs: SharedPreferences,
    private val attributionService: AttributionService,
) : ViewModel() {

    fun start() {
        viewModelScope.launch {
            val uuid = prefs.getString("uuid", null) ?: generateAndStoreUuid()

            OneSignal.initWithContext(application, ONESIGNAL_APP_ID)
            OneSignal.login(uuid)

            val ref = installReferrer.fetch()
            val adId = if (!ref.contains("utm_medium=organic")) {
                AdvertisingIdClient.getAdvertisingIdInfo(application).id
            } else null

            attributionService.post(uuid, ref, adId)
            _state.value = SplashState.LoadWebView(uuid)
        }
    }
}
```

## Як доповідати

```
[security/splash-attribution-flow] WARNING
  <file>:<line>
  На splash-скрині відсутній крок attribution-flow: <missing-step>.
  Як виправити: <specific guidance based on missing step, e.g. "Додайте `OneSignal.initWithContext(application, ONESIGNAL_APP_ID)` у splash flow перед login()" або "Додайте InstallReferrerClient для отримання utm-параметрів">.
  Див.: внутрішня документація команди про attribution-flow.
```

## Виключення

Дозволено через `accepted-risks` для гілки/збірки "без апдейту"
(чисто гра без attribution). Тоді ВСІ кроки 1.b-1.e відсутні навмисно
— достатньо одного запису `accepted-risks` із обґрунтуванням
"non-attribution branch" для цього rule.

Якщо тільки кілька кроків відсутні (наприклад, OneSignal так,
attribution post — ні) — це підозріло, обґрунтування має пояснити
кожен пропущений крок окремо.
