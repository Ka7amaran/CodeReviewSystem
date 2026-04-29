# Android Review System — Design Specification

- **Date:** 2026-04-29
- **Status:** Draft, awaiting user review
- **Author:** Roman (with Claude Opus 4.7)
- **Topic:** Automated Android code-review system based on Claude Code

---

## 1. Context and motivation

Команда розробляє кілька Android-додатків на спільному технологічному стеку
(Kotlin + Jetpack Compose + Hilt + AGP 8.13.x). Кодова база кожного додатку
відрізняється: різні навігаційні бібліотеки (Navigation Compose vs Voyager),
різні рівні крипто-обфускації, різна локальна персистенція (SQLDelight або
відсутня), різні endpoint-патерни (Ktor HTTP vs WebView).

Незважаючи на відмінності, всі додатки проходять через однаковий набір
типових ризиків: пустий `proguard-rules.pro` при `isMinifyEnabled = true`,
hardcoded крипто-seed'и, експортовані Activity без захисту, cleartext-трафік,
відсутність тестів критичної логіки, неузгодженості між `applicationId`,
`namespace` і деклараціями в Asana.

Code-review таких проектів зараз ручний і непослідовний: різні рев'юери
помічають різні речі, чек-ліст живе у головах. Мета цієї системи —
**формалізувати чек-ліст як набір машиночитних правил і виконувати його
агентами Claude Code** при кожному ревью, з консистентним звітом, який
можна вставити в Google Doc для шерингу.

---

## 2. Scope

### 2.1. In scope

Чотири категорії перевірок:

1. **Стандартне Code Review** — стиль Kotlin/Compose, архітектура (Clean/MVVM),
   продуктивність (recomposition), best practices Hilt/coroutines.
2. **Аудит ризиків перед публікацією** — Android Manifest (дозволи,
   експортовані компоненти, cleartext, deeplinks), gradle (debuggable,
   minify), Google Play policies.
3. **Перевірка обфускації** — стан `proguard-rules.pro`, покриття критичних
   класів `-keep`-правилами, наявність junk-обфускації як такої, ефективність
   обраного підходу до приховування секретів.
4. **Опціональна валідація проектних значень** — `applicationId`, `namespace`,
   `minSdk`/`targetSdk` проти декларованих у проектному `CLAUDE.md`. Без
   автоматизованого порівняння з Asana.

Тестовий аудит **виключений** — окрема команда тестування додатків працює
нативно після code-review.

### 2.2. Out of scope

- Збірка проекту (`./gradlew assembleRelease`) і будь-який динамічний аналіз
  APK/AAB (apkanalyzer, MobSF). Система — чисто статична.
- Інтеграція з Asana API. Очікувані ID/секрети не зчитуються з Asana
  автоматично; за замовчуванням не валідуються.
- Інтеграція з Google Docs API. Звіт генерується як файл; вставка в Doc —
  ручна.
- Інтеграція з CI/CD. MVP — тільки локальний запуск з Android Studio.
- Автоматичні фікси коду. Система **тільки доповідає**.
- Тести самого плагіна як автоматизація. Перевірка регресій — ручна
  (smoke-test, секція 12).

---

## 3. High-level architecture

### 3.1. Дві сутності системи

**(а) Repository плагіна** — single source of truth. Окремий Git-репозиторій
(наприклад, `your-org/claude-android-review`), що додається у Claude Code
Plugin Marketplace. Містить оркестратор, sub-agent'и, правила, документацію.

**(б) Тонка обв'язка в Android-проекті** — `.claude/CLAUDE.md` у корені
кожного проекту, який буде ревью'ватися. 10–30 рядків. Містить специфіку
саме цього додатку (project-id, очікувані значення, критичні класи,
прийняті ризики).

### 3.2. Топологія агентів

Один **оркестратор** диспатчить роботу трьом **спеціалізованим sub-agent'ам**,
які працюють паралельно:

```
                    /android-review (orchestrator)
                              │
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
    style-auditor      security-auditor    obfuscation-auditor
         │                    │                    │
         └────────────────────┼────────────────────┘
                              ▼
              cross-cutting analysis + final report
```

Кожен sub-agent окремо викликається через свою slash-команду
(`/android-review-style`, `/android-review-security`,
`/android-review-obfuscation`) — для точкових перевірок без оркестратора.

### 3.3. Розв'язка "агенти ↔ правила" (R2)

Sub-agent'и не вшивають правила у свої system prompts. Вони **читають**
файли з директорії `rules/<category>/*.md` і застосовують їх по черзі.
Це дозволяє додавати/редагувати правила без редагування агентів і
закладає основу під майбутній R3-шар (per-project overrides).

### 3.4. Потік виконання (happy path)

1. Code-reviewer: `cd ~/StudioProjects/<project>; claude`.
2. Claude Code підвантажує плагін з marketplace, читає `.claude/CLAUDE.md`
   проекту як проектний контекст.
3. Code-reviewer: `/android-review`.
4. Оркестратор:
   - читає `rules/` плагіна;
   - парсить декларативні секції з `CLAUDE.md` проекту;
   - паралельно диспатчить 3 sub-agent'и;
   - чекає всі звіти;
   - виконує cross-cutting аналіз;
   - формує фінальний звіт;
   - зберігає його у двох форматах у `.claude/reports/` всередині проекту.
5. Code-reviewer читає звіт у терміналі, копіює `.gdoc.txt` у Google Doc.

### 3.5. Архітектурні принципи

- **Read-only sandbox.** Плагін не модифікує файли проекту. На рівні
  `permissions.deny` явно заборонені `Edit`, `Write`, мутаційні `Bash`.
  Захист від prompt-injection через файли проекту.
- **Partial-tolerant.** Якщо один sub-agent падає (timeout, помилка LLM),
  оркестратор продовжує з іншими. Звіт містить розділ Agent failures.
- **Fail-loud, не fail-silent.** Будь-яка проблема (невалідне правило,
  поламаний CLAUDE.md, відсутність проекту) — повідомляється, не приховується.
- **Дані замість логіки.** Правила — markdown-файли, не код. Система
  розробляється і розширюється редагуванням текстових файлів.

---

## 4. Plugin repository structure

```
claude-android-review/
│
├── .claude-plugin/
│   └── plugin.json                   # маніфест плагіна
│
├── README.md
├── CHANGELOG.md
│
├── commands/                         # точки входу (slash-команди)
│   ├── android-review.md             # /android-review
│   ├── android-review-style.md
│   ├── android-review-security.md
│   └── android-review-obfuscation.md
│
├── agents/                           # system prompts агентів
│   ├── orchestrator.md
│   ├── style-auditor.md
│   ├── security-auditor.md
│   └── obfuscation-auditor.md
│
├── rules/                            # декларативний реєстр правил (R2)
│   ├── _schema.md                    # документація формату
│   ├── _template.md                  # шаблон для нового правила
│   ├── style/
│   │   └── *.md
│   ├── security/
│   │   └── *.md
│   └── obfuscation/
│       └── *.md
│
├── docs/
│   ├── how-to-add-a-rule.md
│   ├── project-claude-md-template.md # шаблон CLAUDE.md для Android-проекту
│   ├── architecture.md               # копія цього документа
│   └── smoke-test.md                 # ручний smoke-test plan
│
└── examples/
    ├── good-proguard-rules.pro
    ├── good-android-manifest.xml
    └── good-claude-md-for-project.md
```

### 4.1. `commands/`

Тонкі обгортки. Кожен файл — markdown із описом команди і посиланням на
відповідного агента. Містить блок `permissions.deny`, який гарантує
read-only поведінку (див. секцію 11).

### 4.2. `agents/`

System prompts агентів. Кожен агент знає **процедуру** ("як перевіряти
security в Android-проекті"), але **не конкретні правила**. Замість списку
перевірок — інструкція "Прочитай усі файли з `rules/<твоя-категорія>/`,
для кожного застосуй процедуру з його `## Що перевірити`, формуй звіт за
шаблоном `## Як доповідати`".

### 4.3. `rules/`

Серце системи. Кожне правило — окремий markdown-файл (формат — секція 5).
Категорії — `style/`, `security/`, `obfuscation/`. Плоска структура,
без вкладених підкатегорій (зменшує когнітивне навантаження при пошуку).

### 4.4. `docs/`

`how-to-add-a-rule.md` — гайд для людини, що пише нове правило.
`project-claude-md-template.md` — шаблон, який копіюється у новий
Android-проект. `architecture.md` — копія цього документа всередині
плагіна. `smoke-test.md` — ручний регресійний чек-ліст.

### 4.5. `examples/`

Референси для звітів. Коли правило радить "виправ так-то" — звіт може
послатися на конкретний приклад тут.

### 4.6. Версіонування плагіна

Semver:
- **patch** — формулювання правил, дрібні фікси.
- **minor** — нові правила, нові sub-agent'и, нові команди.
- **major** — несумісна зміна формату `rules/*.md`, зміна публічного API
  команд, зміна формату `CLAUDE.md`.

`CHANGELOG.md` — обов'язковий. Code-reviewer повинен мати можливість
зрозуміти, що нова версія плагіна додасть нові червоні точки в його звітах.

### 4.7. Дистрибуція

Code-reviewer виконує **один раз** на машині:

```
/plugin marketplace add github:your-org/claude-android-review
/plugin install android-review@your-org-marketplace
```

Далі в будь-якому Android-проекті: `cd <проект> && claude && /android-review`.

---

## 5. Rule file format

### 5.1. Структура файлу `rules/<category>/<rule-id>.md`

```markdown
---
id: security/no-cleartext-traffic
severity: error
category: security
applies-to:
  - AndroidManifest.xml
  - res/xml/network_security_config.xml
since: "1.0.0"
---

# No cleartext traffic in release builds

## Чому це важливо

(2–6 речень: бізнес/безпековий контекст, чому правило існує. Без цього
розробник не зрозуміє, чому йому це показують. Скорочує review fatigue.)

## Що перевірити

(Пронумерований чек-ліст для агента. Це програма правила: агент проходить
пункти послідовно, для кожного дає висновок.)

## Як це виглядає у поганому проекті

```xml
... приклад порушення ...
```

## Як це має виглядати

```xml
... приклад правильної конфігурації ...
```

## Як доповідати

```
[<rule-id>] <SEVERITY>
  <file>:<line>
  <конкретне формулювання знахідки>
  Fix: <короткий фіксер>.
  See: <посилання на examples/ або зовнішнє>.
```

## Виключення

(Коли правило можна вимкнути через `accepted-risks` у проектному CLAUDE.md.
Якщо "Жодних" — вимикається тільки правкою файлу, не overrides.)
```

### 5.2. Frontmatter (5 обов'язкових полів)

| Поле          | Тип                  | Призначення                                                                |
|---------------|----------------------|----------------------------------------------------------------------------|
| `id`          | `<category>/<slug>`  | Унікальний ідентифікатор. Використовується у звітах і `accepted-risks`.    |
| `severity`    | `error\|warning\|info` | Error блокує реліз, warning — обов'язково розглянути, info — спостереження. |
| `category`    | `style\|security\|obfuscation` | Дублює перший сегмент `id`, дозволяє швидку фільтрацію.                  |
| `applies-to`  | список glob-патернів | Для pre-filter'у: якщо у проекті немає підходящих файлів, тіло правила не читається. |
| `since`       | semver-рядок         | Версія плагіна, в якій правило з'явилося. Для CHANGELOG-tracking.          |

### 5.3. Алгоритм застосування правил агентом

(Псевдо-флоу, формується у system prompt sub-agent'а.)

1. Прочитати **тільки frontmatter** усіх файлів з `rules/<своя-категорія>/`.
2. Для кожного правила: перевірити `applies-to` проти файлів проекту.
   Якщо немає жодного відповідного — пропустити, не читати тіло.
3. Прочитати тіло тих, що пройшли.
4. Прочитати `accepted-risks` з `.claude/CLAUDE.md` проекту. Якщо правило
   у списку і його секція `## Виключення` дозволяє виключення —
   пропустити.
5. Для кожного активного правила: виконати програму з `## Що перевірити`.
6. Якщо знайдено порушення — сформувати запис за шаблоном `## Як доповідати`.
7. Зібрати знахідки у markdown-звіт із розбивкою по severity.

### 5.4. Чому markdown із frontmatter

Тіло правила — інструкція для LLM. Markdown LLM розуміє найкраще.
Frontmatter (YAML) — лише для метаданих, що потрібні для filtering/routing
до читання тіла. Спроба запхати "Що перевірити" у структуроване поле
(YAML/JSON) перетворила б правило на нечитабельний звіт. Принцип:
**метадані — структура, контент — проза.**

---

## 6. Project `.claude/CLAUDE.md` format

Файл у корені Android-проекту. Виконує **дві функції одразу**:
- (а) проектний контекст для Claude Code (підхоплюється автоматично);
- (б) машиночитні декларації для плагіна (parsed by orchestrator).

### 6.1. Шаблон

```markdown
# Project context for Claude Code

(Вільний короткий опис проекту. Може бути порожнім.)

---

# Android Review configuration

## project-id

juice-master-factory

## expected-values

applicationId: com.thinkplay.tp3g
namespace: com.fruity.juicemasterfactory
minSdk: 26
targetSdk: 36

## critical-classes

- com.fruity.juicemasterfactory.core.decrypt.**
- com.fruity.juicemasterfactory.data.model.**

## sensitive-files

- app/src/main/java/com/fruity/juicemasterfactory/core/decrypt/**

## accepted-risks

# rule-id: justification

## rule-overrides

# (R3-плейсхолдер. Поки не парситься.)
```

### 6.2. Секції (значення і поведінка)

| Секція           | Призначення                                                                                                       |
|------------------|-------------------------------------------------------------------------------------------------------------------|
| `project-id`     | Людиночитний ідентифікатор. Потрапляє в назву звітів та заголовок.                                                |
| `expected-values`| Опціональні очікувані значення для базової валідації (`applicationId`, `namespace`, `minSdk`, `targetSdk`). Якщо порожньо — перевірка пропускається без помилки. |
| `critical-classes`| Glob-патерни класів, які мають бути збережені `-keep`-правилами в `proguard-rules.pro`. Без цієї секції obfuscation-агент використовує fallback-евристику за іменами. |
| `sensitive-files`| Glob-патерни файлів, що потребують підвищеної уваги security-агента (зашифровані рядки, junk-обфускація, hardcoded secrets). |
| `accepted-risks` | `<rule-id>: <обґрунтування>`. Вимикає правило, якщо його секція `## Виключення` це дозволяє. Якщо ні — агент попереджає в звіті, що ризик прийняти не можна. |
| `rule-overrides` | R3-хук. Поки не парситься, секція є плейсхолдером для майбутнього розширення (per-project параметри правил). |

### 6.3. Поведінка при відсутності файлу

Плагін **не падає**. Агенти переходять у дефолтний режим:
- `expected-values` — перевірки пропускаються;
- `critical-classes` — obfuscation-агент шукає за патернами імен
  (`*crypto*`, `*decrypt*`, `*Cipher*`, `*Auth*`, `Key*`) і пропонує
  задекларувати знайдене;
- `sensitive-files` — security-агент сканує всі kotlin-файли з вищим
  порогом для false positives;
- `accepted-risks` — порожньо, нічого не вимикається.

Звіт у такому режимі шумніший — це навмисно. Code-reviewer повинен
**відчути** користь і захотіти заповнити CLAUDE.md.

### 6.4. Хто і коли заповнює

Code-reviewer створює `.claude/CLAUDE.md` при першому ревью проекту.
Копіює `examples/good-claude-md-for-project.md` із плагіна, заповнює
4 секції на основі коду + Asana-картки. ~5–10 хвилин разової роботи.
Файл комітиться в репозиторій проекту як технічний артефакт.

---

## 7. Final report

### 7.1. Структура

Звіт виводиться оркестратором у термінал (markdown) одним повідомленням.
Паралельно зберігається у файли (секція 8).

```
# Android Review report — <project-id>

**Date:** <YYYY-MM-DD HH:mm>
**Plugin version:** <semver>
**Project:** <absolute path>
**CLAUDE.md:** found ✓ | missing ⚠️ | partially parseable ⚠️

---

## Summary

| Category      | Errors | Warnings | Info | Skipped |
|---------------|--------|----------|------|---------|
| Style         |        |          |      |         |
| Security      |        |          |      |         |
| Obfuscation   |        |          |      |         |
| **Total**     |        |          |      |         |

**Verdict:** <READY | READY WITH WARNINGS | NOT READY | INCOMPLETE>

---

## 🔴 Errors (must fix)

(Кожна знахідка за шаблоном `## Як доповідати` правила.)

---

## 🟡 Warnings (recommended)

(Те саме.)

---

## ℹ️ Info

(Те саме.)

---

## 🔗 Cross-cutting findings

(Знахідки, що з'явились із зіставлення звітів декількох агентів.
Найважливіша частина звіту, форма sub-agent'и не побачать самостійно.)

---

## ⚠️ Agent failures

(Тільки якщо хтось із агентів впав. Назва агента, причина, частковий звіт.)

---

## Skipped rules

(Чому правило не запускалось: applies-to не співпало, accepted-risks
вимкнув його, або frontmatter невалідний.)

---

## Run details

- style-auditor:       <s>, <N> rules applied, <M> findings
- security-auditor:    <s>, <N> rules applied, <M> findings
- obfuscation-auditor: <s>, <N> rules applied, <M> findings
- orchestrator merge:  <s>, <X> cross-cutting findings
- Total wall-clock:    <s>
```

### 7.2. Verdict (4 категорії)

| Verdict                | Умова                                                                          |
|------------------------|--------------------------------------------------------------------------------|
| `READY`                | 0 errors, 0 warnings.                                                          |
| `READY WITH WARNINGS`  | 0 errors, ≥1 warning.                                                          |
| `NOT READY`            | ≥1 error.                                                                      |
| `INCOMPLETE`           | Принаймні один sub-agent не завершив роботу. Verdict обчислений на частковому. |

### 7.3. Шерінг через Google Doc

Звіт зберігається у двох форматах паралельно (формат B, секція 8.2):
- `<project-id>-android-review.md` — стандартний markdown.
- `<project-id>-android-review.gdoc.txt` — переформатований під вставку
  у Google Docs:
  - заголовки `#`/`##`/`###` → ВЕЛИКІ ЛІТЕРИ + порожній рядок;
  - markdown-таблиці → плоский текст із табуляцією між колонками;
  - інлайн-код у backticks — лишається як є (Google Docs показує як текст);
  - чек-маркери (`🔴 🟡 ℹ️ ✓ ❌`) — залишаються емодзі;
  - лінки `[text](url)` → `text (url)`;
  - жодного html/markup, тільки plain UTF-8.

---

## 8. Save behavior

### 8.1. Завжди зберігати

`/android-review` зберігає звіт **завжди**, без флагу. Code-reviewer
запускає ревью, щоб ділитися результатами — отже, файли мають бути на
диску щоразу. Спеціальний `--save` не потрібен.

### 8.2. Куди зберігати (Format B + N3)

Структура `.claude/reports/` всередині проекту:

```
.claude/
├── CLAUDE.md
└── reports/
    ├── <project-id>-android-review.md         # завжди поточний
    ├── <project-id>-android-review.gdoc.txt   # завжди поточний
    └── archive/
        ├── <project-id>-2026-04-29-1423.md
        ├── <project-id>-2026-04-29-1423.gdoc.txt
        ├── <project-id>-2026-04-30-0915.md
        └── <project-id>-2026-04-30-0915.gdoc.txt
```

**Поведінка при кожному запуску:**
1. Якщо існує `<project-id>-android-review.md` — перенести у `archive/`
   з суфіксом `<YYYY-MM-DD-HHmm>`. Те саме для `.gdoc.txt`.
2. Записати новий поточний звіт у обидва формати з чистою назвою.

**Очистка архіву:** ніяка автоматична. Code-reviewer сам видаляє
`archive/`, коли захоче.

### 8.3. Git-ignore

Шаблон `.gitignore` (додається при копіюванні `CLAUDE.md` у новий проект):

```
# Claude Code Android Review
.claude/reports/
```

`.claude/CLAUDE.md` — комітиться (це конфіг ревью).
`.claude/reports/` — ні (це локальні артефакти).

---

## 9. Error handling

### 9.1. Один із sub-agent'ів впав

Оркестратор продовжує роботу. У звіті з'являється розділ
`## ⚠️ Agent failures` з назвою агента і причиною. Verdict стає
`INCOMPLETE`. Часткові знахідки інших агентів — у звіті як зазвичай.

### 9.2. Правило з невалідним frontmatter

Агент пропускає правило, додає у `## Skipped rules`:
```
- security/no-cleartext-traffic — invalid YAML frontmatter (missing `severity`)
```
Не блокує запуск.

### 9.3. CLAUDE.md з частково невалідним форматом

Оркестратор парсить max-tolerantly. Невалідну секцію (наприклад,
`expected-values`) пропускає, в заголовку звіту:
```
**CLAUDE.md:** found ⚠️ (expected-values section unparseable, ignored)
```
Не падає.

### 9.4. Запуск не з кореня Android-проекту

Оркестратор перевіряє наявність `app/build.gradle.kts` або
`app/build.gradle`. Якщо немає — fail-fast:
```
This is not an Android project root. Expected app/build.gradle(.kts)
— not found. Did you cd to the project root before launching claude?
```
Звіт не генерується.

### 9.5. Версія плагіна старша за `since` правил

Не повинно траплятись (плагін атомарний). Якщо станеться — правило
пропускається з ворнінгом у `## Skipped rules`.

### 9.6. Принцип

Система **никогда не падає мовчки**. Будь-яка проблема — або у звіті,
або у явному термінал-повідомленні з зрозумілим follow-up.

---

## 10. Permissions and security

### 10.1. Read-only sandbox

У `commands/*.md` явно прописано:

```yaml
permissions:
  deny:
    - Edit
    - Write
    - "Bash(rm:*)"
    - "Bash(git:*)"
    - "Bash(curl:*)"
    - "Bash(wget:*)"
  allow:
    - Read
    - Glob
    - Grep
    - "Bash(find:*)"
    - "Bash(cat:*)"
    - "Bash(ls:*)"
```

(Конкретний остаточний список — у плані імплементації.)

### 10.2. Захист від prompt-injection

Аналізований код потенційно містить prompt-injection (коментарі,
рядкові константи). Read-only sandbox гарантує, що навіть якщо
інструкція з файлу пройде через LLM-узгодженість, harness не виконає
мутаційну дію.

### 10.3. Принцип найменших привілеїв

Плагін має тільки ті інструменти, що потрібні для статичного аналізу.
Net-доступ і shell-мутації заборонені на рівні harness'у.

---

## 11. Smoke-test plan (manual regression)

Замість автотестів — ручний прогін на двох реальних проектах перед
кожним релізом нової версії плагіна. ~10 хвилин.

### 11.1. Сценарії

**S1. Juice-Master-Factory — повний прогон.**
- `cd ~/StudioProjects/Juice-Master-Factory; claude; /android-review`.
- Очікуване: verdict `NOT READY`. Мінімум 5 errors:
  cleartext, empty proguard, hardcoded keystore-files in repo,
  namespace-mismatch warning, exported-without-keep cross-cutting.

**S2. Joker-Speed-Seven — повний прогон.**
- `cd ~/StudioProjects/Joker-Speed-Seven; claude; /android-review`.
- Очікуване: verdict `NOT READY`. Мінімум 4 errors:
  empty proguard, hardcoded `USER_SEED`, junk-obfuscation effectiveness,
  deeplink-host-without-validation, hardcoded keystore у repo.

**S3. Точкова перевірка.**
- У Juice: `/android-review-obfuscation`.
- Очікуване: < 2 секунд, тільки obfuscation-категорія в звіті.

**S4. Дегенерат-кейс.**
- `cd /tmp; claude; /android-review`.
- Очікуване: fail-fast із зрозумілим повідомленням.

**S5. Без CLAUDE.md.**
- Тимчасово перейменувати `.claude/CLAUDE.md` у Juice.
- Запустити `/android-review`.
- Очікуване: працює, шум вищий, відсутні `expected-values` і
  `critical-classes` перевірки. Повернути файл назад.

### 11.2. Документація

`docs/smoke-test.md` у плагіні. Перед кожним мінорним/мажорним
релізом — code-reviewer проганяє всі 5, фіксує очікуване, порівнює
з фактичним.

### 11.3. Прийнятий ризик

Тихі регресії можливі, якщо smoke-test пропускається. Це усвідомлений
trade-off проти витрат на автоматизовані тести (toolchain для fixtures,
golden-files, інвалідація при кожному переформулюванні prompt'у).

---

## 12. Versioning and lifecycle

### 12.1. Plugin versioning

Semver на рівні `.claude-plugin/plugin.json`:
- patch: формулювання правил, дрібні фікси.
- minor: нові правила, нові sub-agent'и, нові команди.
- major: зміна формату `rules/*.md`, зміна публічного API команд,
  зміна формату `CLAUDE.md`.

### 12.2. CHANGELOG

Обов'язковий. Кожний реліз перераховує: додані правила, видалені/
deprecated правила, зміни у severity, зміни у форматі звіту.

### 12.3. Rule deprecation

Видаляти правило не можна без deprecation-циклу:
1. Один minor-реліз: severity знижується до `info`, у тіло додається
   `## Deprecated: <причина>`.
2. Через мінімум одну minor-версію — правило видаляється у наступному
   minor-релізі. CHANGELOG явно це декларує.

---

## 13. Open items (не блокують MVP)

- **R3 (rule-overrides)** — секція в CLAUDE.md проекту вже існує
  (плейсхолдер), але не парситься. Активувати, коли вперше виникне
  потреба перевизначати параметри правил per-project.
- **CI integration** — плагін за дизайном викличеться з `claude` CLI,
  тому інтеграція в GitHub Actions не вимагає змін плагіна.
  Окремий артефакт (action / workflow YAML) — поза scope цього дизайну.
- **Asana validation** — якщо колись з'явиться вимога порівнювати
  `expected-values` із Asana-карткою, це окремий MCP-сервер +
  розширення `expected-values` секції. Не зараз.
- **Auto-fix mode** — поза scope. Якщо колись захочеться "запропонувати
  патч у git stash" — це окремий major-реліз з повним переглядом
  permissions і UX.

---

## 14. Decisions log (як прийшли до цього дизайну)

| Рішення                                                  | Альтернативи                              | Чому обрано                                                                              |
|----------------------------------------------------------|-------------------------------------------|------------------------------------------------------------------------------------------|
| Marketplace-плагін                                       | Просто Git-репо, скіли локально           | Природний flow Claude Code, легке оновлення для команди.                                 |
| Тонкий CLAUDE.md у проекті                               | Без проектного шару                       | Проекти різні, без per-project context'у звіти будуть або шумними, або неточними.        |
| Виклик з терміналу AS slash-командою                     | External Tool у меню AS, окремий UI       | AS уже інтегрує Claude Code; будь-яка обгортка — зайвий шар.                             |
| Оркестратор + 3 паралельні sub-agent'и                   | Моноліт, окремі скіли без оркестратора    | Cross-cutting analysis (security ↔ obfuscation) критичний для аудиту перед публікацією.  |
| Правила як декларативні markdown-файли                   | Hardcoded у prompt'и агентів              | 50+ правил у моноліті ставатимуть нечитаними; декларація дозволяє data-only еволюцію.    |
| 5 полів frontmatter (без `play-policy-related`)          | 6 полів                                   | Користувач вирішив, що окрема pre-release категорія зайва на цьому етапі.                |
| 3 рівні severity (error / warning / info)                | 4 рівні (+ critical)                      | Достатньо. Critical = error із посиленим формулюванням.                                  |
| Tests-auditor виключений                                 | Включений як 4-й sub-agent                | Окрема команда тестування покриває це нативно після code-review.                         |
| Asana-валідація — не пріоритет                           | MCP-інтеграція з Asana                    | Дані Asana валідні за замовчуванням; вартість інтеграції непропорційна.                  |
| Format B (md + gdoc.txt поруч)                           | Format A (тільки md), Format C (Docs API) | Чисте відображення в Google Docs гарантовано; без OAuth/MCP/мережі.                      |
| Завжди зберігати, без `--save` флагу                     | Зберігати тільки з флагом                 | Звіт призначений для шерингу — файли потрібні щоразу.                                    |
| N3 (стабільна назва + archive/)                          | N1 (перезапис), N2 (only previous)        | Чиста основна назва + повна історія без втрат.                                           |
| Manual smoke-test замість автотестів                     | Автоматизовані fixtures + golden          | Користувач явно виключив автотести; ручний прогін — компромісний регресійний контроль.   |
| Read-only sandbox обов'язково                            | Дозволити Edit/Write                      | Захист від prompt-injection, що особливо актуально для проектів із junk-обфускацією.     |
