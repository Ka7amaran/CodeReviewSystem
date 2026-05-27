---
id: meta/dev-bundle-match
severity: suspicious
category: meta
applies-to:
  - app/build.gradle.kts
  - app/build.gradle
since: "2.8.0"
---

# Очікуваний test bundle для розробника на час code review

## Інваріант

Коли проєкт належить одному з відомих розробників (визначається імʼям
**батьківської папки** проєкту), значення `defaultConfig.applicationId`
у `app/build.gradle(.kts)` має точно дорівнювати закріпленому test-бандлу
цього розробника (див. каталог нижче). На час code review та тестування
дев перемикає `applicationId` на свій test-бандл; production-значення
повертається лише перед релізом. Розбіжність сигналізує: або дев забув
перемкнути бандл, або проєкт лежить у не-своєму каталозі.

## Каталог dev → test bundle

| `<DevName>` (батьківська папка) | `applicationId` |
|---|---|
| `Dima`    | `com.proxima.dfm` |
| `Elchin`  | `easy.sudoku.puzzle.solver.free` |
| `Grisha`  | `com.ecffri.arrows` |
| `Nikita`  | `com.mobile.legends` |
| `Marina`  | `com.mergegames.gossipharbor` |
| `Danik`   | `com.haoplay.game.and.exilium` |

Імена case-sensitive (саме `Dima`, не `dima`).

## Як перевірити

Це **резолв identity з orchestrator-промпта + читання gradle**, а не grep-перевірка.

1. У dispatch-промпті до агента orchestrator має передавати рядок
   `Project parent folder: <name>` (див. `commands/android-review.md` Step 4).
   Прочитати це значення. Якщо рядка немає **або** значення дорівнює
   літеральному `<unknown>` (fallback orchestrator'а при збої
   `basename`/`dirname`) — правило не може застосуватися (помилка
   середовища) → emit `OBSERVATION` («orchestrator не передав робочий
   Project parent folder — пропустіть або оновіть commands/android-review.md»).
2. Якщо `<name>` точно збігається з одним із ключів каталогу
   (case-sensitive) — `expected = mapping[<name>]`. Перейти до п.3.
3. Якщо `<name>` НЕ з каталогу — правило **не застосовне** → виводиться
   під «Пропущені перевірки» з причиною
   `project parent folder "<name>" not in known devs catalog`,
   жодного фіндінга.

> Чому асиметрія: відсутність поля у промпті (п.1) — це помилка
> orchestrator'а, тому гучно (OBSERVATION). Відсутність `<name>` у
> каталозі (п.3) — штатна ситуація (проєкт стороннього походження),
> тому тихо.

4. Прочитати `app/build.gradle.kts` (або `app/build.gradle`), знайти блок
   `android { defaultConfig { applicationId = "..." } }`. Витягти точне
   значення літерала.
5. Порівняти exact string з `expected`:
   - збіг → інваріант виконано, додати у «Перевірені інваріанти»;
   - розбіжність або `applicationId` відсутній → finding `SUSPICIOUS`.
6. Варіанти/flavor-суфікси (`debug { applicationIdSuffix = ".debug" }`,
   `productFlavors { … applicationId = … }`) у v1 **не враховуються** —
   перевіряємо тільки `defaultConfig.applicationId`. Якщо в майбутньому
   зʼявиться кейс, де release-flavor легітимно перевизначає → внести через
   `accepted-deviations` у проєктному CLAUDE.md.

## Як виглядає поломка

Проєкт у `~/StudioProjects/Dima/some-app/` (тобто orchestrator передав
`Project parent folder: Dima`), файл `app/build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        applicationId = "com.realproduct.shipped"   // ❌ не test-bundle Dima
        // ...
    }
}
```

## Як виглядає правильно

Той самий шлях:

```kotlin
android {
    defaultConfig {
        applicationId = "com.proxima.dfm"   // ✅ test-bundle Dima
        // ...
    }
}
```

## Як доповідати

Варіант — значення не збігається:

```
[meta/dev-bundle-match] SUSPICIOUS
  app/build.gradle.kts:<line>
  Проєкт у каталозі `<DevName>`, але defaultConfig.applicationId = "<actual>" — очікувався test-bundle "<expected>". Це може значити, що дев забув перемкнути бандл на test перед рев'ю, або проєкт у не-своєму каталозі.
  Як виправити: змініть `defaultConfig.applicationId` на "<expected>" перед рев'ю/тестуванням; перед релізом — поверніть production-значення.
  Див.: rules/meta/dev-bundle-match.md (каталог dev→bundle).
```

Варіант — applicationId відсутній:

```
[meta/dev-bundle-match] SUSPICIOUS
  app/build.gradle.kts:<line of defaultConfig block>
  Проєкт у каталозі `<DevName>`, але defaultConfig.applicationId не задано — очікувався test-bundle "<expected>".
  Як виправити: додайте `applicationId = "<expected>"` у defaultConfig перед рев'ю/тестуванням; перед релізом — поверніть production-значення.
  Див.: rules/meta/dev-bundle-match.md (каталог dev→bundle).
```

## Виключення

Допускається через `accepted-deviations` у `.claude/CLAUDE.md` з явною причиною:
- maintenance-рев'ю вже випущеної апки, де bundle = production;
- дев тимчасово допомагає в проєкті іншого дева;
- release-flavor легітимно перевизначає `applicationId` (наприклад,
  `productFlavors { release { applicationId = "..." } }`) — вкажіть це
  у причині (нагадування з п.6 алгоритму);
- проєкт легітимно живе поза `~/StudioProjects/` (зовнішнє місце) — там
  батьківська папка не з каталогу і так пропускає правило тихо, exception
  не потрібен.
