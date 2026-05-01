---
id: style/adaptive-icon
severity: info
category: style
applies-to:
  - app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
  - app/src/main/AndroidManifest.xml
since: "1.5.0"
---

# Адаптивна іконка (foreground + background) і themed icon

## Чому це важливо

Android 8.0+ (API 26+) підтримує **адаптивні іконки** — два шари
(foreground + background), які лаунчер мімітує під свою форму
(круг/squircle/teardrop/тощо). Без адаптивної іконки твій launcher
буде показувати legacy-`ic_launcher.png`, що часто виглядає вирізаним
або з білими кутами на сучасних оболонках Pixel/Samsung One UI.

Android 13+ (API 33+) додав **themed icon** — монохромна версія, яка
підбирає колір під wallpaper (системна тема). Не обов'язкова, але
"за замовчуванням" Pixel-користувачі активно цим користуються; без
themed icon твій додаток виглядає чужим у themed-launcher'і.

## Що перевірити

1. **Адаптивна іконка:**
   - Файл `app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` має
     існувати.
   - Він має містити `<adaptive-icon>` як корінь, з `<foreground>` і
     `<background>` всередині.
   - Якщо `mipmap-anydpi-v26/ic_launcher.xml` відсутній — flag.

2. **Themed icon (Android 13+):**
   - У тому самому `<adaptive-icon>` має бути `<monochrome>`-шар.
   - Якщо `<monochrome>` відсутній — flag (info, бо Android 13+
     fallback'ить на foreground).

3. **Manifest:**
   - `application` має `android:icon="@mipmap/ic_launcher"` АБО
     `android:roundIcon="@mipmap/ic_launcher_round"`.

## Як це виглядає у поганому проекті

```
res/
  mipmap-mdpi/ic_launcher.png
  mipmap-hdpi/ic_launcher.png
  ...
  (немає mipmap-anydpi-v26/ic_launcher.xml)
```

## Як це має виглядати

```xml
<!-- res/mipmap-anydpi-v26/ic_launcher.xml -->
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
```

## Як доповідати

```
[style/adaptive-icon] INFO
  <file>
  Адаптивна іконка <відсутня | без monochrome-шару>.
  Як виправити: створіть `app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` з `<adaptive-icon>` (foreground + background + monochrome для themed icon на Android 13+). У Android Studio: ПКМ на res → New → Image Asset → Launcher Icons (Adaptive and Legacy).
  Див.: https://developer.android.com/develop/ui/views/launch/icon_design_adaptive
```

## Виключення

Дозволено через `accepted-risks` для додатків, які мають свідомо
"плоску" іконку з усіх боків. Обґрунтування обов'язкове.
