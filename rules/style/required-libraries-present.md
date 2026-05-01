---
id: style/required-libraries-present
severity: info
category: style
applies-to:
  - gradle/libs.versions.toml
  - app/build.gradle.kts
  - app/build.gradle
since: "1.4.0"
---

# Обов'язкові бібліотеки атрибуції присутні

## Чому це важливо

Команда має стандартний набір бібліотек, які мають бути присутні в
кожному додатку з логікою attribution + push-нотифікаціями:

1. **OneSignal** (`com.onesignal:OneSignal`) — push-нотифікації.
2. **Install Referrer** (`com.android.installreferrer:installreferrer`)
   — отримання referrer-параметрів від Google Play (для розрізнення
   organic vs paid traffic).
3. **Play Services Ads Identifier**
   (`com.google.android.gms:play-services-ads-identifier`) —
   отримання `adId` для signed-in пристроїв (потрібен для
   неорганічних установок).

Якщо одна з них відсутня — флоу attribution на splash зламається:
користувач не зможе бути правильно класифікований як organic vs paid,
сервер відповість "невизначено", а далі бізнес-логіка втрачає
точність.

## Що перевірити

1. Прочитати `gradle/libs.versions.toml` (за наявності) або
   `app/build.gradle.kts` напряму.
2. Перевірити наявність кожної з трьох бібліотек у `dependencies` або
   `[libraries]`:
   - OneSignal: рядок містить `OneSignal` (case-insensitive) або
     `onesignal:OneSignal`.
   - Install Referrer: рядок містить `installreferrer`.
   - Play Services Ads Identifier: рядок містить
     `play-services-ads-identifier`.
3. Якщо одна з них відсутня — flag (info, бо може бути проектне
   рішення для гри без атрибуції).

## Як це виглядає у поганому проекті

```toml
# libs.versions.toml — без attribution-бібліотек
[libraries]
androidx-core-ktx = { ... }
androidx-activity-compose = { ... }
# OneSignal, installreferrer, play-services-ads-identifier — ВІДСУТНІ
```

## Як це має виглядати

```toml
# libs.versions.toml — повний attribution-стек
[versions]
onesignal = "5.1.35"
referrer = "2.2"
playServicesAdsIdentifier = "18.3.0"

[libraries]
onesignal = { module = "com.onesignal:OneSignal", version.ref = "onesignal" }
referrer = { group = "com.android.installreferrer", name = "installreferrer", version.ref = "referrer" }
play-services-ads-identifier = { group = "com.google.android.gms", name = "play-services-ads-identifier", version.ref = "playServicesAdsIdentifier" }
```

(Версії довільні, головне — наявність бібліотек.)

## Як доповідати

```
[style/required-libraries-present] INFO
  gradle/libs.versions.toml або app/build.gradle.kts
  Обов'язкова бібліотека "<library-name>" відсутня в залежностях проєкту.
  Як виправити: додайте бібліотеку `<library-coordinates>` у `libs.versions.toml` або напряму у `dependencies` блок `app/build.gradle.kts`. Якщо проєкт навмисно без attribution-стеку (наприклад, версія "без апдейту"), задекларуйте через `accepted-risks`.
  Див.: внутрішня документація команди про дві версії білда (з attribution / без).
```

## Виключення

Дозволено через `accepted-risks` для гілки/збірки "без апдейту"
(чисто гра без attribution-стеку). Обґрунтування обов'язкове, бо
має бути явно задокументовано, що це навмисний вибір — інакше
ризик випадкової відсутності бібліотек у production-збірці.
