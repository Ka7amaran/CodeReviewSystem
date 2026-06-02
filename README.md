# android-review

Claude Code плагін для функціонального ревʼю Android-проєктів
(Kotlin/Compose/Hilt). Перевіряє attribution-flow, WebView/CustomTabs
конфіг, crypto-патерни і perf-обсервації через **dataflow tracing** —
а не структурний grep. Звіт у `.claude/reports/`.

Поточна версія — **v2.9.0**. Повна історія: [CHANGELOG.md](CHANGELOG.md).

---

## Встановлення (один раз)

У будь-якій Claude Code сесії:

```
/plugin marketplace add github:Ka7amaran/CodeReviewSystem
/plugin install android-review@android-review-marketplace
```

Плагін кешується у `~/.claude/plugins/cache/...`. Команди резолвлять
шлях автоматично — додаткова конфігурація не потрібна.

---

## Quickstart (раз на проєкт)

```
cd ~/StudioProjects/<DevName>/<your-android-project>
claude
/android-review:android-review-init     # один раз — створити CLAUDE.md
/android-review:android-review          # власне ревʼю; запускати скільки треба
```

Все. Звіт зʼявиться у `.claude/reports/<project-id>-android-review.md`.

---

## Що робить `android-review-init`

1. **Pre-flight «completeness check»** *(v2.9.0+).* Перш ніж щось
   створити, шукає 3 маркери реальної апки — WebView/CustomTabs,
   Install Referrer Client, OneSignal SDK — у `app/build.gradle*`,
   `AndroidManifest.xml`, `app/src/main/{java,kotlin}/`. Якщо знайдено
   **≤ 1 з 3**, зупиняється і питає підтвердження («це справді повна
   версія?»). Захист від кейсу «запулив проєкт, забув перемкнутися на
   правильну гілку, згенерував CLAUDE.md з порожнього стабу».
2. Створює `.claude/CLAUDE.md` з двома полями:
   - `project-id` — `basename` теки проєкту.
   - `project-type` — `with-attribution` чи `no-attribution`
     (детектиться з gradle: `OneSignal` / `installreferrer` /
     `play-services-ads-identifier`).
3. Додає `.claude/reports/` у `.gitignore` проєкту.

Якщо `.claude/CLAUDE.md` уже існує — команда відмовляється
перезаписати. Щоб перегенерувати: `rm .claude/CLAUDE.md` і запустити
init заново.

---

## Що робить `android-review`

1. Резолвить `project-id`, `PROJECT_PARENT_FOLDER` (для `meta/`-правил),
   читає `.claude/CLAUDE.md`.
2. Запускає subagent **`functional-validator`** з whitelisted-доступом
   до `rules/{flow,webview,crypto,perf,meta}/`. Агент:
   - Зчитує всі правила.
   - Виконує **dataflow tracing** на коді проєкту.
   - Порівнює знайдені факти з інваріантами правил.
3. Архівує попередній звіт у `.claude/reports/archive/<project-id>-<TS>.md`
   і пише новий — `.claude/reports/<project-id>-android-review.md`.
4. Друкує короткий summary у термінал (повний звіт — у файлі).

---

## Категорії правил

| Категорія  | Що перевіряє                                       | Приклад                                                                          |
|------------|----------------------------------------------------|----------------------------------------------------------------------------------|
| `flow/`    | attribution / landing / redirect / POST-encoding   | Install Referrer → landing URL → WebView/CustomTabs — ланцюжок цілий             |
| `webview/` | WebView/CustomTabs конфіг, cleartext, JS-bridges   | `android:usesCleartextTraffic="true"` заборонено *(v2.8.0)*                      |
| `crypto/`  | Coverage encoding-патернів, string-literal coverage| Чутливі string literals обернуті в proven-encoding helper                        |
| `meta/`    | Розробницькі / проєктні інваріанти                 | `applicationId` дева збігається з закріпленим test-бандлом *(v2.8.0)*            |
| `perf/`    | Лагідні observation-правила (вердикт не блокують)  | Structure observations                                                           |

### Severity

- **critical** — блокує реліз; виправити обовʼязково.
- **suspicious** — прапор у звіт, але ревʼю проходить; огляньте.
- **observation** — інформативно; на загальний вердикт не впливає.

---

## Заглушення конкретних правил

У `.claude/CLAUDE.md`, розділ `## accepted-deviations`:

```
crypto/string-literal-encoding-coverage: legacy module, переписуємо в Q3
flow/landing-mechanism-present: navigation поки через старий хелпер
```

Рядки з `#` ігноруються. Один не-коментарний рядок = одне заглушене
правило. Завжди вказуйте **чому** — це коментар для майбутнього себе.

---

## Структура репо

```
commands/   # /android-review-init, /android-review
agents/     # functional-validator (subagent)
rules/      # flow/, webview/, crypto/, meta/, perf/ — markdown-правила
docs/       # архітектура + how-to-add-a-rule
examples/   # приклади звітів
CHANGELOG.md
```

Звіти у `.claude/reports/` ігноруються git-ом — це локальний output,
не конфіг.

---

## Що далі

- **Додати правило** — `docs/how-to-add-a-rule.md` + шаблон
  `rules/_template.md`.
- **Архітектура / dataflow tracing** —
  `docs/specs/2026-04-29-android-review-system-design.md`.
- **Реліз-нотатки** — `CHANGELOG.md`.

---

## E2E-санітарка (раз на реліз)

Швидкі перевірки після upgrade плагіна:

1. На **«реальній» апці** → init має пройти тихо
   (`Pre-flight: 3/3 markers detected (PASS)`) і створити CLAUDE.md.
2. На **стаб-чекауті** (порожня `main`) → init має показати warning з
   гілкою/SHA/іншими гілками і AskUserQuestion. Відповідь
   «Ні — зупини» → жодних файлів не створено.
3. `/android-review` на реальній апці → звіт у `.claude/reports/`,
   попередній звіт переїхав у `archive/`.
