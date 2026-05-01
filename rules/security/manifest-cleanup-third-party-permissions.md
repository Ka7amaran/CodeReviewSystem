---
id: security/manifest-cleanup-third-party-permissions
severity: warning
category: security
applies-to:
  - app/src/main/AndroidManifest.xml
since: "1.4.0"
---

# Видалення зайвих дозволів сторонніх SDK через `tools:node="remove"`

## Чому це важливо

OneSignal, Install Referrer, Play Services Ads Identifier та інші
типові SDK при merge'у манифесту автоматично додають десятки
permissions, які грі не потрібні: BIND_GET_INSTALL_REFERRER_SERVICE,
WAKE_LOCK, RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE, READ_APP_BADGE,
а також купа vendor-specific badge-permissions (Samsung, HTC, Sony,
Huawei, Oppo, Apex, Solo, Everything). Незайві permissions:
1. Збільшують розмір списку дозволів у Play Console (Data Safety).
2. Викликають питання у користувача при перегляді permissions.
3. Можуть стати тригером Play Console policy-warnings.
4. Збільшують атаку-surface, навіть якщо самі дозволи не використовуються.

Стандартна практика — явно блокувати ці permissions через
`tools:node="remove"` у manifest'і додатку.

## Що перевірити

1. Переконатись, що в `app/src/main/AndroidManifest.xml` присутні
   `tools:node="remove"` записи для **усіх** наступних permissions:
   - `com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE`
   - `<package>.permission.C2D_MESSAGE` або `com.dts.freefireth.permission.C2D_MESSAGE` (вендор-специфічно)
   - `<package>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`
   - `android.permission.WAKE_LOCK`
   - `android.permission.RECEIVE_BOOT_COMPLETED`
   - `android.permission.FOREGROUND_SERVICE`
   - `android.permission.READ_APP_BADGE`
   - `android.permission.VIBRATE` (якщо гра не використовує вібрацію)
   - Усі badge-permissions:
     - `com.sec.android.provider.badge.permission.READ`
     - `com.sec.android.provider.badge.permission.WRITE`
     - `com.htc.launcher.permission.READ_SETTINGS`
     - `com.htc.launcher.permission.UPDATE_SHORTCUT`
     - `com.sonymobile.home.permission.PROVIDER_INSERT_BADGE`
     - `com.anddoes.launcher.permission.UPDATE_COUNT`
     - `com.majeur.launcher.permission.UPDATE_BADGE`
     - `com.huawei.android.launcher.permission.CHANGE_BADGE`
     - `com.huawei.android.launcher.permission.READ_SETTINGS`
     - `com.huawei.android.launcher.permission.WRITE_SETTINGS`
     - `com.oppo.launcher.permission.READ_SETTINGS`
     - `com.oppo.launcher.permission.WRITE_SETTINGS`
     - `me.everything.badger.permission.BADGE_COUNT_READ`
     - `me.everything.badger.permission.BADGE_COUNT_WRITE`
2. Зафіксувати кожен відсутній запис як окрему знахідку (один permission
   = один finding).

## Як це виглядає у поганому проекті

```xml
<manifest ...>
    <!-- Жодного <uses-permission tools:node="remove" /> для зайвих SDK-permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <application ...>
```

## Як це має виглядати

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <uses-permission
        android:name="com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE"
        tools:node="remove" />
    <uses-permission
        android:name="android.permission.WAKE_LOCK"
        tools:node="remove" />
    <!-- ...та решта зайвих permissions через tools:node="remove" -->

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application ...>
```

## Як доповідати

```
[security/manifest-cleanup-third-party-permissions] WARNING
  app/src/main/AndroidManifest.xml
  Дозвіл "<permission-name>" не вилучено через tools:node="remove" — він проникає у фінальний manifest з SDK при merge'у.
  Як виправити: додайте <uses-permission android:name="<permission-name>" tools:node="remove" /> у app/src/main/AndroidManifest.xml. Не забудьте підключити namespace xmlns:tools="http://schemas.android.com/tools" на корінь <manifest>.
  Див.: https://developer.android.com/build/manage-manifests#node_markers
```

## Виключення

Дозволено через `accepted-risks` для конкретного permission, якщо ваш
додаток справді його використовує (наприклад, гра з вібрацією — тоді
`android.permission.VIBRATE` не блокується). Обґрунтування обов'язкове.
