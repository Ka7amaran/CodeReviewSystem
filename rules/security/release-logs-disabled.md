---
id: security/release-logs-disabled
severity: warning
category: security
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "1.4.0"
---

# Логи мають бути вимкнені у release-збірці

## Чому це важливо

`Log.d()`, `Log.v()`, `Log.i()` та `println()` у production-APK:
1. Залишають внутрішні параметри/стани/секрети у `logcat` — будь-який
   ADB-доступ читає всю історію.
2. Потенційно протікають внутрішню структуру програми (структуру
   сервера, attribution-параметри, UUID користувача).
3. Сповільнюють додаток — `String`-форматування виконується навіть
   коли логи нікому не потрібні.
4. Збільшують розмір APK через залишені log-string-літерали.

Стандартна практика: загорнути logging у перевірку `BuildConfig.DEBUG`,
або використати ProGuard-rule, що видаляє виклики `android.util.Log.*`
із release-bytecode'а:

```
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
```

## Що перевірити

1. У файлах матчу `applies-to` шукати прямі виклики `Log.d(`, `Log.v(`,
   `Log.i(` (case-sensitive), а також `println(`.
2. Для кожного знайденого виклику перевірити, чи він у блоці
   `if (BuildConfig.DEBUG)` (читай 5 рядків вище) або обгорнутий у
   debug-only функцію.
3. Якщо виклик НЕ обгорнутий — flag.
4. Альтернативно: перевірити, чи в `app/proguard-rules.pro` присутній
   `-assumenosideeffects class android.util.Log` блок. Якщо так, прямі
   виклики OK (вони вирізаються R8).

## Як це виглядає у поганому проекті

```kotlin
class GameViewModel : ViewModel() {
    fun onTap(score: Int) {
        Log.d("GameVM", "tap, score=$score, uuid=$userId")
        // …
    }
}
```

## Як це має виглядати

Варіант 1: guard на рівні коду:

```kotlin
if (BuildConfig.DEBUG) {
    Log.d("GameVM", "tap, score=$score")
}
```

Варіант 2: ProGuard-видалення:

```
# app/proguard-rules.pro
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
```

Тоді прямі `Log.d(...)` залишаються у коді, але R8 вирізає їх із
release-APK.

## Як доповідати

```
[security/release-logs-disabled] WARNING
  <file>:<line>
  Прямий виклик `<Log.method or println>(...)` — у release-APK залишиться у logcat.
  Як виправити: оберніть в `if (BuildConfig.DEBUG) { ... }`, або додайте `-assumenosideeffects class android.util.Log { public static *** d(...); ... }` у app/proguard-rules.pro.
  Див.: https://developer.android.com/studio/build/shrink-code#strip-native-libraries
```

## Виключення

Дозволено через `accepted-risks` для `Log.e(...)` (error-level — мають
залишатися у release для debugging crash reports). У такому разі
обґрунтування обов'язкове.
