---
id: flow/initial-startup-checklist
severity: suspicious
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
requires-project-type: with-attribution
---

# Початкові дії після запуску апки виконуються (всі 6 кроків)

## Інваріант

Для `with-attribution` проєктів усі 6 початкових дій мають
відбуватися при запуску апки (у будь-якому порядку, у будь-якому
місці коду — не обов'язково на splash):

1. Отримання або генерація UUID.
2. Ініціалізація push-сервісу (OneSignal або еквівалент) з login(uuid).
3. Отримання Install Referrer (будь-яким SDK).
4. Отримання adId (будь-яким способом).
5. Запит на бекенд-домен.
6. Подальший роутинг (WebView/CustomTabs або гра).

## Як перевірити

Це dataflow-перевірка, не grep. Агент має простежити стартову
послідовність викликів від точки входу (`Application.onCreate`,
launcher Activity's `onCreate`, перший Composable у NavGraph) і
переконатись, що усі 6 дій **досяжні** у dataflow стартового флоу.

**Timing не пиниться.** Інваріант — *факт виконання у session*, не
*до першого UI-рендеру*. Крок задовольняє контракт, якщо він досяжний
з точки входу хоч у `onCreate` Application'а, хоч у `LaunchedEffect`
на пізнішому екрані (наприклад, у Splash чи Policy composable), хоч
у `ViewModel.init` ViewModel'а, що інстанціюється під час нормального
сценарію. Команда свідомо може ініціалізувати push-сервіс у момент
відкриття WebView (а не у Application.onCreate) — це валідна
архітектура. Головне — щоб крок дійсно виконувався під час session,
а не був мертвим кодом.

1. Знайти точку входу: `class * : Application()` із
   `@HiltAndroidApp`/`AndroidEntryPoint` АБО launcher Activity з
   `<intent-filter>` MAIN/LAUNCHER.
2. Слідкувати за стартовим dataflow: які класи інстанціюються,
   які корутини запускаються у `onCreate` / `LaunchedEffect` /
   `init` блоках, які callback'и тригеряться під час нормального
   сценарію (включно з переходом на splash → policy → WebView).
3. Для кожного з 6 кроків знайти **факт виконання** (без вимог
   до конкретного SDK і без вимог до timing'у):
   - UUID: будь-який вираз, що зчитує/пише `uuid`/`user_id`/
     `device_id` із persistence layer + умовна генерація.
   - Push init: будь-який виклик схожий на
     `OneSignal.initWithContext(...)` або еквівалент.
   - Install Referrer: будь-який виклик до Install Referrer Library
     АБО SDK типу AppsFlyer/Tenjin/Adjust.
   - adId: будь-який виклик до `AdvertisingIdClient` АБО
     еквівалент SDK.
   - Domain request: будь-який HTTP-виклик до зовнішнього бекенду
     (URL детектується з коду — літеральний або encrypted-at-rest;
     зашифрований URL — очікуваний team-patten, не finding).
   - Routing: видимий decision-point що веде або у Game-екран,
     або у WebView/CustomTabs.
4. Кожен пропущений крок = окрема знахідка `suspicious`-severity.
   Чотири і більше пропущених кроків поспіль → промоут до
   `critical` (це не просто пропуск окремої дії, це відсутність
   стартового флоу взагалі).

## Як виглядає поломка

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // нічого зі стартового flow не виконується
    }
}

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { GameScreen() }   // одразу гра, без attribution
    }
}
```

## Як виглядає правильно

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        OneSignal.initWithContext(this, BuildConfig.ONESIGNAL_APP_ID)
    }
}

class StartupRouter @Inject constructor(
    private val uuidStore: UuidStore,
    private val referrerClient: InstallReferrerClient,
    private val adIdClient: AdIdClient,
    private val backend: BackendApi,
) {
    suspend fun startup(): RouteDecision {
        val uuid = uuidStore.getOrCreate()
        OneSignal.login(uuid)
        val ref = referrerClient.fetch()
        val adId = adIdClient.fetch()
        val response = backend.notify(uuid, ref, adId)
        return response.route
    }
}
```

(Конкретні класи/SDK не важливі — важливо що всі 6 дій присутні
і досяжні з точки входу.)

## Як доповідати

```
[flow/initial-startup-checklist] SUSPICIOUS
  <file>:<line>   (точка входу або найближче місце де крок мав би відбутися)
  Початковий флоу не містить кроку "<step-name>" — <конкретне пояснення dataflow>.
  Як виправити: додайте відповідний виклик у стартову послідовність до першого UI-рендеру.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.1
```

## Виключення

Дозволено через `accepted-deviations` для конкретних кроків, якщо
проєкт усвідомлено пропускає (наприклад, push-нотифікації вимкнено
бізнес-рішенням). Обґрунтування обов'язкове.
