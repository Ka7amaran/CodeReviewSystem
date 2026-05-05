---
id: flow/uuid-persistence
severity: suspicious
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
requires-project-type: with-attribution
---

# UUID зберігається між сесіями і переюзується

## Інваріант

Якщо при першому запуску згенерувано UUID, при наступному запуску
той самий UUID має бути прочитаний із persistence (а не згенерований
заново). Storage-механізм не важливий: SharedPreferences,
EncryptedSharedPreferences, Room, DataStore, Firebase, будь-яке
локальне або хмарне сховище.

## Як перевірити

1. Знайти точку, де UUID генерується — будь-який виклик типу
   `UUID.randomUUID()`, `SecureRandom`, або власної generator-функції,
   результат якої присвоюється змінній з ім'ям, що містить `uuid`/
   `user_id`/`device_id`.
2. Перевірити, що згенероване значення **зберігається** одразу
   після генерації — виклик `prefs.edit().putString(...)`,
   `dataStore.edit { ... }`, `dao.insert(...)`, тощо.
3. Знайти точку, де UUID **читається** при старті — виклик
   `prefs.getString(key, null)`, `dataStore.data.first()`,
   `dao.get()`, тощо.
4. Перевірити, що генерація відбувається **тільки якщо читання
   повернуло null/empty** (тобто паттерн "read-or-create").
5. Перевірити, що прочитаний UUID передається далі (у push login,
   у POST до бекенду, у WebView URL).

Якщо генерація відбувається безумовно (без read-check) — UUID
переписується кожного запуску, attribution ламається. Це **critical**.

Якщо UUID читається але потім ніде не використовується — це теж
**critical** (фактично передається null до бекенду).

## Як виглядає поломка

```kotlin
class UserStorage(private val prefs: SharedPreferences) {
    fun getUuid(): String {
        val uuid = UUID.randomUUID().toString()   // ❌ генерується щоразу
        prefs.edit().putString("uuid", uuid).apply()
        return uuid
    }
}
```

## Як виглядає правильно

```kotlin
class UserStorage(private val prefs: SharedPreferences) {
    fun getOrCreateUuid(): String {
        return prefs.getString("uuid", null) ?: run {
            val newUuid = UUID.randomUUID().toString()
            prefs.edit().putString("uuid", newUuid).apply()
            newUuid
        }
    }
}
```

## Як доповідати

```
[flow/uuid-persistence] CRITICAL    (або SUSPICIOUS, залежно від проблеми)
  <file>:<line>
  UUID <генерується безумовно при кожному старті | читається, але далі не використовується | відсутній read-or-create патерн>.
  Як виправити: реалізуйте паттерн "якщо UUID існує → переюз; якщо ні → згенеруй і збережи". Storage будь-який.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.2
```

## Виключення

Жодних. Persistence UUID між сесіями — фундаментальна вимога
attribution-флоу. Якщо вона не виконується — апка ламає бізнес-логіку
і це критичний баг.
