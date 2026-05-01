---
id: style/webp-images
severity: info
category: style
applies-to:
  - app/src/main/res/drawable/**
  - app/src/main/res/drawable-mdpi/**
  - app/src/main/res/drawable-hdpi/**
  - app/src/main/res/drawable-xhdpi/**
  - app/src/main/res/drawable-xxhdpi/**
  - app/src/main/res/drawable-xxxhdpi/**
since: "1.5.0"
---

# Графічні ресурси у форматі WebP

## Чому це важливо

WebP при тій же якості важить на 25-50% менше за PNG/JPG. Для
типового Android-додатку з 100+ drawable-ресурсами це -2…-10 МБ APK
(або AAB). Менший APK = вища conversion на Google Play (Play Store
показує розмір установки на сторінці магазину).

Android 4.0+ підтримує WebP нативно. Для loseless WebP — Android
4.3+ (API 18). У всіх сучасних проектах (`minSdk 26+`) — повна
підтримка.

Android Studio має вбудований конвертер: ПКМ на drawable → "Convert
to WebP".

## Що перевірити

1. Перебрати всі файли в `applies-to`.
2. Для кожного файла з розширенням `.png` або `.jpg`/`.jpeg`:
   - Якщо це **icon** (лежить у `mipmap-*/`, не `drawable/`) — пропустити (icons часто потребують PNG для adaptive-icon system).
   - Якщо файл `> 50 КБ` — flag.
3. Для drawable-ресурсів формату `.9.png` (nine-patch) — пропустити (вони не конвертуються у WebP).

## Як це виглядає у поганому проекті

```
res/drawable/
  background_main.png       (450 KB)
  splash_logo.png           (180 KB)
  card_back.jpg             (320 KB)
```

## Як це має виглядати

```
res/drawable/
  background_main.webp      (180 KB)
  splash_logo.webp          (60 KB)
  card_back.webp            (90 KB)
```

## Як доповідати

```
[style/webp-images] INFO
  <file>
  Графічний ресурс у форматі <PNG|JPG> (<size> КБ) — рекомендовано конвертувати у WebP для зменшення розміру APK.
  Як виправити: у Android Studio ПКМ на файл → "Convert to WebP" → виберіть якість 75-85%. WebP підтримується нативно з API 14, lossless — з API 18.
  Див.: https://developer.android.com/studio/write/convert-webp
```

## Виключення

Дозволено через `accepted-risks` для:
- Nine-patch файлів (`.9.png`) — не конвертуються.
- Файлів, які мають точний bit-perfect рендеринг (рідко).
- Vector drawable (`.xml`) — взагалі не зачіпаються правилом.
