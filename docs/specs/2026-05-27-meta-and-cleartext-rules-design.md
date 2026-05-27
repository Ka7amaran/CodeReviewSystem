# Design: `meta/dev-bundle-match` + `webview/cleartext-traffic-disabled`

**Дата:** 2026-05-27
**Цільова версія плагіна:** `2.8.0`
**Статус:** затверджений дизайн, готовий до implementation-плану

---

## Context

Користувач веде шість Android-розробників, кожен зі своїм каталогом-родителем
у `~/StudioProjects/<DevName>/` (`Dima`, `Elchin`, `Grisha`, `Nikita`, `Marina`,
`Danik`). У кожного дева закріплений **test bundle** — `applicationId`, який
має бути виставлений у `defaultConfig` на час code review та тестування
(production-значення повертається перед релізом). Якщо дев забув перемкнути
бандл — рев'ю ризикує проводитися по «не тому» артефакту identity.

Окремо: у Manifest апок іноді з'являється `android:usesCleartextTraffic="true"`.
Оскільки апки використовують **WebView/CustomTabs** як основну поверхню
контенту, cleartext-дозвіл означає, що будь-який `http://`-URL у цих
компонентах передається у відкритому вигляді — це baseline-security issue.

Цей реліз додає **два правила**, які закривають обидві дірки автоматично, і
**попутно лагодить регресію**, виявлену під час дизайну: правила з категорії
`rules/perf/` (існують з v2.1.0) не дискаверяться агентом, бо в його prompt
зашитий жорсткий список `{flow,webview,crypto}`.

## Out of scope

- Зміни в `init`-команді чи `.claude/CLAUDE.md`-шаблоні (нові правила читають
  існуючі джерела — gradle, manifest, шлях проєкту).
- Підтримка `productFlavors`/`applicationIdSuffix` у meta-правилі (тільки
  `defaultConfig.applicationId` exact match — найясніший контракт для v1;
  розширення — окремий реліз за реальною потребою).
- Глибокий аналіз NSC у cleartext-правилі — лише дві типові форми (`<base-config>`,
  `<domain-config>` з `cleartextTrafficPermitted="true"`) як `OBSERVATION`;
  доменні нюанси та fallback-логіка NSC залишаються за людиною.

---

## Rule #1 — `meta/dev-bundle-match`

**Шлях:** `rules/meta/dev-bundle-match.md`
**Категорія:** `meta` (нова)
**Severity:** `suspicious`
**Applies-to:** `app/build.gradle.kts`, `app/build.gradle`

### Інваріант

Коли проєкт розташований під `~/StudioProjects/<DevName>/<project>/`,
`defaultConfig.applicationId` у `app/build.gradle(.kts)` має точно дорівнювати
закріпленому test-бандлу цього розробника (каталог нижче). Якщо шлях не
матчиться — правило не застосовне (тиха пропустка).

### Каталог dev → test bundle (вбудовано в тіло правила)

| `<DevName>` (батьківська папка) | `applicationId` |
|---|---|
| `Dima`    | `com.proxima.dfm` |
| `Elchin`  | `easy.sudoku.puzzle.solver.free` |
| `Grisha`  | `com.ecffri.arrows` |
| `Nikita`  | `com.mobile.legends` |
| `Marina`  | `com.mergegames.gossipharbor` |
| `Danik`   | `com.haoplay.game.and.exilium` |

Імена case-sensitive (як на скріні фактичної структури каталогу).

### Алгоритм перевірки (Як перевірити)

1. Прочитати значення `Project parent folder: <name>` з власного dispatch
   prompt (його туди ставить orchestrator, бо агент сам не може запустити
   `pwd`/`basename`).
2. Перевірити, чи `<name>` точно збігається з одним із ключів каталогу
   (case-sensitive). Якщо ні — правило **не застосовне** → виводиться під
   «Пропущені перевірки» з причиною `project parent folder "<name>" not in
   known devs catalog`, жодного фіндінга.
3. Якщо так — `expected = mapping[<name>]`.
4. Прочитати `app/build.gradle.kts` (або `.gradle`), знайти блок
   `android { defaultConfig { applicationId = "..." } }`, витягти точне
   значення літерала.
5. Порівняти exact string з `expected`. Збіг → «Перевірені інваріанти».
   Розбіжність або відсутність `applicationId` → `SUSPICIOUS`.

> Примітка: правило не намагається перевірити, чи проєкт фізично під
> `~/StudioProjects/` — це не потрібно. Достатньо того, що батьківська
> папка має імʼя одного з відомих девів. Якщо хтось випадково створив
> папку `Dima/` деінде — то це проблема структури, а не правила.

### Edge cases (зафіксовані)

- **Глибина шляху:** перевіряється тільки безпосередня батьківська папка.
  `StudioProjects/Dima/legacy/app/` → парент = `legacy` → skip.
- **Case sensitivity:** `Dima` ≠ `dima`. Якщо хтось перейменує папку
  малими — правило перестане застосовуватися (це поведінка за дизайном:
  нехай імена каталогів збігаються зі скріном).
- **Варіанти/flavor суфікси:** v1 ігнорує. `release { applicationIdSuffix = ".prod" }`
  не впливає на перевірку.
- **`namespace` vs `applicationId`:** правило перевіряє лише `applicationId`
  (installed package). `namespace` (R-class) не зачіпається.

### Виключення (accepted-deviations)

Допускається через явну причину: maintenance-рев'ю вже випущеної апки,
тимчасова допомога в чужому проєкті. Якщо проєкт фізично поза `~/StudioProjects/` —
правило тихо пропускається саме, exception не потрібен.

### Шаблон фіндінга

```
[meta/dev-bundle-match] SUSPICIOUS
  app/build.gradle.kts:<line of applicationId>
  Проєкт у каталозі `<DevName>`, але defaultConfig.applicationId = "<actual>" —
  очікувався test-bundle "<expected>". Це може значити, що дев забув перемкнути
  бандл на test перед рев'ю, або проєкт у не-своєму каталозі.
  Як виправити: змініть `defaultConfig.applicationId` на "<expected>" перед
  рев'ю/тестуванням; перед релізом — поверніть production-значення.
  Див.: rules/meta/dev-bundle-match.md
```

---

## Rule #2 — `webview/cleartext-traffic-disabled`

**Шлях:** `rules/webview/cleartext-traffic-disabled.md`
**Категорія:** `webview`
**Severity:** `critical`
**Applies-to:** `app/src/main/AndroidManifest.xml`,
`app/src/main/res/xml/network_security_config.xml`

### Інваріант

Атрибут `android:usesCleartextTraffic` на `<application>` у
`app/src/main/AndroidManifest.xml` **не може мати значення `"true"`**.
Допустимо: атрибут відсутній (за умови `targetSdk >= 28`, де дефолт = false)
або `"false"`. NSC-override з `cleartextTrafficPermitted="true"` емітимо як
`OBSERVATION`, бо рішення легітимності за людиною.

### Алгоритм перевірки

1. Прочитати `app/src/main/AndroidManifest.xml`.
2. Знайти елемент `<application>`.
3. Атрибут `android:usesCleartextTraffic`:
   - `"true"` → finding `CRITICAL`.
   - `"false"` → інваріант виконано (Перевірені інваріанти).
   - **відсутній + `targetSdkVersion >= 28`** → інваріант виконано (дефолт OS = false).
   - **відсутній + `targetSdkVersion < 28`** → finding `CRITICAL` (на старому
     target дефолт = true, тобто фактично cleartext дозволено).
4. Незалежно від п.3, якщо `<application>` має `android:networkSecurityConfig="@xml/<name>"`:
   - відкрити вказаний XML у `app/src/main/res/xml/`;
   - наявність `<base-config cleartextTrafficPermitted="true">` →
     `OBSERVATION` («NSC дозволяє cleartext глобально, обходить manifest»);
   - наявність `<domain-config cleartextTrafficPermitted="true">` →
     `OBSERVATION` («NSC дозволяє cleartext для конкретних доменів — перевірте навмисність»).
5. Перевіряється тільки `app/src/main/AndroidManifest.xml`. `debug/AndroidManifest.xml`
   ігнорується (легітимний debug-overlay для локальної розробки).

### Edge cases (зафіксовані)

- **API < 28 без атрибута:** трактуємо як CRITICAL (історичний дефолт = true).
  `targetSdkVersion` читається з тієї самої gradle-секції, що й `applicationId`
  у меті.
- **Multi-module:** перевіряється тільки `app/`-модуль (shipped manifest).
- **NSC через ресурс:** агент має прочитати referenced XML. Якщо референс битий
  (файл не існує) — `OBSERVATION` («NSC файл `@xml/<name>` не знайдено»).
- **NSC inline через `tools:replace`/manifest-merging нюанси** не аналізуються
  у v1 — рідкісний кейс, окреме розширення за потребою.

### Виключення (accepted-deviations)

Допускається з reason: legacy-бекенд без TLS, локальний dev-сервер. Рекомендоване
обхідне рішення — винести cleartext-дозвіл у `debug/AndroidManifest.xml`-overlay,
тоді release-маніфест чистий і exception не потрібен.

### Шаблон фіндінга

```
[webview/cleartext-traffic-disabled] CRITICAL
  app/src/main/AndroidManifest.xml:<line>
  <application android:usesCleartextTraffic="true"> — апка явно дозволяє
  HTTP-трафік. WebView/CustomTabs/HTTP-клієнти можуть відкривати http:// URL у
  відкритому вигляді, що є витоком даних.
  Як виправити: видаліть атрибут (на API 28+ дефолт = false) або явно поставте
  android:usesCleartextTraffic="false".
  Див.: rules/webview/cleartext-traffic-disabled.md
```

NSC-варіант:

```
[webview/cleartext-traffic-disabled] OBSERVATION
  app/src/main/res/xml/<nsc-file>.xml:<line>
  NSC-конфіг дозволяє cleartextTrafficPermitted="true" (<base-config|domain-config>).
  Це обходить manifest-заборону для відповідних доменів.
  Як виправити: переконайтеся, що дозвіл навмисний; інакше — заберіть атрибут.
  Див.: rules/webview/cleartext-traffic-disabled.md
```

---

## Cross-cutting changes

| Файл | Зміна | Причина |
|---|---|---|
| `agents/functional-validator.md` | Замінити `rules/{flow,webview,crypto}/` на `rules/{flow,webview,crypto,perf,meta}/` у трьох місцях (рядки **3** — description, **12** — Your job, **35** — Step 1). | Без цього агент не побачить `meta/`. **Попутно лагодить регресію**: `perf/` теж не входив у дискаверi з v2.1.0, тож існуючі perf-правила починають фактично виконуватися (severity: observation, тож вердикт не може стати гіршим). |
| `commands/android-review.md` (Step 4 dispatch prompt) | У prompt до агента додати рядок `Project parent folder: <basename "$(dirname "$PWD")">` (обчислити через Bash перед dispatch, як і `PLUGIN_ROOT`). | Агент має tools `[Read, Glob, Grep, mcp__...]` — **без Bash**. Сам визначити імʼя батьківської папки CWD він не може; orchestrator зобовʼязаний це передати, інакше `meta/dev-bundle-match` не зможе резолвити `<DevName>`. |
| `rules/_schema.md` | У секції «Frontmatter» рядок `category: flow \| webview \| crypto` → додати `meta` і `perf`. У секції «Categories» додати короткий опис `meta/`. | Косметика — щоб schema не брехала про дозволені категорії. |
| `.claude-plugin/plugin.json` | `"version": "2.7.0"` → `"2.8.0"`. | Реліз. |
| `CHANGELOG.md` | Додати запис `v2.8.0` зі змістом цього дизайну. | Конвенція релізів. |

### Вплив на існуючі проєкти

- `init`-команда **не змінюється**; existing `.claude/CLAUDE.md` файли
  лишаються сумісні; re-init не потрібен.
- Нові правила застосовуються до існуючих проєктів автоматично з наступним
  прогоном `/android-review:android-review`.
- `perf/` правила почнуть з'являтися в розділі «Спостереження» звіту — раніше
  їх там не було, бо агент їх не дискаверив.

---

## Verification

End-to-end чек-ліст ручного тестування на v2.8.0:

1. **`meta/dev-bundle-match` happy path:**
   - помістити проєкт у `~/StudioProjects/Dima/test-app/`, `applicationId =
     "com.proxima.dfm"` → інваріант у «Перевірені»;
   - той самий проєкт з `applicationId = "com.other.value"` → finding
     `SUSPICIOUS` у звіті, фрагмент шаблону присутній.
2. **`meta/dev-bundle-match` skip:**
   - проєкт у `~/Desktop/some-app/` → «Пропущені перевірки» з причиною
     `project not under ~/StudioProjects/<KnownDev>/`, жодного фіндінга;
   - проєкт у `~/StudioProjects/UnknownDev/some-app/` → така ж пропустка.
3. **`webview/cleartext-traffic-disabled` happy path:**
   - manifest з `android:usesCleartextTraffic="true"` → `CRITICAL`;
   - manifest без атрибута + `targetSdk = 33` → інваріант виконано;
   - manifest без атрибута + `targetSdk = 26` → `CRITICAL` (історичний дефолт).
4. **NSC OBSERVATION:**
   - manifest з `networkSecurityConfig="@xml/nsc"` + NSC з
     `<base-config cleartextTrafficPermitted="true">` → `OBSERVATION` у звіті.
5. **Регресія `perf/`:**
   - на будь-якому проєкті, що має повільний `Application.onCreate`,
     перевірити, що `perf/startup-blocking` тепер з'являється в розділі
     «ℹ️ Спостереження» (раніше відсутнє).
6. **Сумарний контракт:**
   - вердикт прогону не може погіршитися від додавання observation-правил;
   - вердикт може стати `🔴 НЕ ГОТОВО`, якщо cleartext-правило відловить
     `"true"` — це за дизайном.

---

## Rollout

- Реліз як v2.8.0 одним коммітом, типове повідомлення у формі попередніх
  релізних коммітів (`feat: v2.8.0 — meta/dev-bundle-match + cleartext-traffic
  + agent category whitelist fix`).
- Існуючі користувачі плагіна підхопять через `/plugin marketplace update`;
  ніяких ручних дій на боці Android-проєктів не потрібно.
