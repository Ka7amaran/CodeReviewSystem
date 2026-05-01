---
id: obfuscation/encrypted-sharedpreferences-for-uuid
severity: info
category: obfuscation
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "1.4.0"
---

# Зберігання UUID/секретів через EncryptedSharedPreferences

## Чому це важливо

Звичайний `SharedPreferences` зберігається у XML-файлі під
`/data/data/<package>/shared_prefs/`. На root-пристрої або через
`adb backup` (де backup-rules дозволяють) цей файл легко читається —
включно з UUID користувача, attribution-параметрами, авторизаційними
токенами.

`EncryptedSharedPreferences` із `androidx.security` AES-шифрує і ключі,
і значення. Master-key зберігається в Android KeyStore (TEE-protected).

Особливо важливо для:
- UUID користувача (точка ідентифікації для server-side flows).
- Auth-токенів від OneSignal/власного сервера.
- Adіd, що зберігається після першого attribution-запиту.

## Що перевірити

1. У файлах матчу `applies-to` знайти випадки, коли зберігається UUID
   або токен — тригер: рядок містить `getSharedPreferences(` або
   `PreferenceManager.getDefaultSharedPreferences(`, ПЛЮС в тому ж
   методі/класі присутні токени `uuid`, `token`, `secret`, `key`,
   `auth` (case-insensitive).
2. Якщо знайдено — перевірити, чи це `EncryptedSharedPreferences`:
   рядок містить `EncryptedSharedPreferences.create(` АБО клас
   імпортує `androidx.security.crypto.EncryptedSharedPreferences`.
3. Якщо це звичайний `SharedPreferences` для UUID/auth — flag (info).

## Як це виглядає у поганому проекті

```kotlin
class UserStorage(context: Context) {
    private val prefs = context.getSharedPreferences("user", Context.MODE_PRIVATE)

    fun saveUuid(uuid: String) {
        prefs.edit().putString("uuid", uuid).apply()  // зберігається у plain XML
    }
}
```

## Як це має виглядати

```kotlin
class UserStorage(context: Context) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val prefs = EncryptedSharedPreferences.create(
        context,
        "user-secure",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun saveUuid(uuid: String) {
        prefs.edit().putString("uuid", uuid).apply()
    }
}
```

Плюс залежність:

```toml
androidx-security-crypto = { module = "androidx.security:security-crypto", version = "1.1.0-alpha06" }
```

## Як доповідати

```
[obfuscation/encrypted-sharedpreferences-for-uuid] INFO
  <file>:<line>
  Звичайний SharedPreferences використовується для зберігання UUID/auth-токенів. На root-пристрої або через adb backup ці значення доступні у plain XML.
  Як виправити: замініть на `EncryptedSharedPreferences.create(...)` із залежністю `androidx.security:security-crypto`. Master-key зберігається в Android KeyStore.
  Див.: https://developer.android.com/topic/security/data
```

## Виключення

Дозволено через `accepted-risks`, якщо у SharedPreferences зберігаються
тільки non-sensitive значення (gameplay state, progress, settings) і
жодного UUID/токена. Обґрунтування обов'язкове — ім'я файла prefs та
перелік ключів, що там зберігаються.
