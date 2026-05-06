---
id: perf/startup-blocking
severity: observation
category: perf
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.1.0"
---

# Точки блокування main thread на старті

## Інваріант

Стартовий шлях апки (від `Application.onCreate` до першого UI-frame)
не повинен містити синхронних блокуючих операцій на main thread.
Кожна заблокована операція збільшує time-to-first-frame і потенційно
викликає ANR-warning.

Це **observation**-правило: воно ніколи не блокує реліз і не входить
у Verdict, але дає developer'у конкретний список точок для оптимізації.

## Як перевірити

Для кожної функції, що викликається з `Application.onCreate` /
launcher Activity's `onCreate` / першого Composable у NavGraph, агент
шукає **синхронні блокуючі операції на main thread**:

1. **Synchronous SharedPreferences read** — виклик `getString(...)` /
   `getInt(...)` / etc. **поза** `Dispatchers.IO` корутиною.
   `SharedPreferences` спочатку lazy-loads весь XML файл синхронно;
   на холодному старті це 30-100ms на main thread.
2. **Crypto operations** — `Cipher.getInstance` / `SecretKeySpec` /
   `MessageDigest` / `Mac` поза IO-context. `AES init` коштує 5-50ms
   на bottom-tier пристроях.
3. **Network calls без timeout** — `InstallReferrerClient.startConnection`
   або еквівалент без явного timeout (30 сек default). На повільному
   з'єднанні splash висить.
4. **JSON parsing великих рядків** — `Json.decodeFromString` /
   `Gson.fromJson` / `Moshi` на main thread.
5. **`SystemClock.sleep` / `Thread.sleep`** — будь-яке намагання
   "почекати" на main thread.

Кожна знайдена точка — окремий `observation`-finding з конкретним
рядком коду і пропозицією як винести у `Dispatchers.IO`.

## Як виглядає поломка

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val prefs = getSharedPreferences("user", MODE_PRIVATE)
        val uuid = prefs.getString("uuid", null)              // ❌ sync на UI thread
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding") // ❌ AES init на UI thread
        // ...
    }
}
```

## Як виглядає правильно

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        applicationScope.launch(Dispatchers.IO) {
            val prefs = getSharedPreferences("user", MODE_PRIVATE)
            val uuid = prefs.getString("uuid", null)
            val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
            // ...
        }
    }
}

// або краще: DataStore замість SharedPreferences (async by design)
val Context.userDataStore: DataStore<Preferences> by preferencesDataStore("user")
```

## Як доповідати

```
[perf/startup-blocking] OBSERVATION
  <file>:<line>
  На стартовому шляху виявлено синхронну блокуючу операцію: <SharedPreferences read | Cipher init | network call without timeout | JSON parse | sleep>. Time-to-first-frame збільшено на ~<estimate>ms.
  Як виправити: винести у `Dispatchers.IO` корутину, або замінити на async-API (DataStore замість SharedPreferences, suspend-based clients замість sync HTTP).
  Див.: https://developer.android.com/topic/performance/vitals/launch-time
```

## Виключення

Дозволено через `accepted-deviations` для конкретної точки, якщо
блокування свідоме (наприклад, init обов'язково має завершитись до
першого frame'у). Обґрунтування обов'язкове.
