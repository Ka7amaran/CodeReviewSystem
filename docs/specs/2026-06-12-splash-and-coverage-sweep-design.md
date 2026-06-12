# Дизайн v2.11.0 — splash-screen-quality + coverage-sweep незадекларованих фіч

**Дата:** 2026-06-12
**Статус:** затверджено користувачем (сесія 2026-06-12)
**Базова версія:** v2.10.0 → **v2.11.0**

---

## Мотивація

Дві прогалини, виявлені на реальних рев'ю (кейс: `Sasha/Fruit-Game`):

1. **Сплеш-скрін ніяк не оцінюється.** Команда хоче, щоб кожна апка
   мала анімований сплеш у тематиці гри — він утримує користувача на
   старті. Зараз жодне правило на це не дивиться.
2. **Плагін мовчить про фічі поза каталогом правил.** У Fruit-Game
   було ~10 механізмів (ADB-гейт, connectivity-гейт через сирий
   Socket:53, ручний AIDL-бінд GMS для GAID, vendored Install
   Referrer зі знятою permission, нативний шар `libvault.so`,
   OneSignal `login(uuid)`, backup-hardening, R8-конфіг), які жодне
   правило не моделює — звіт їх просто не згадав. Рев'юер має бачити:
   що це за фіча, що вона робить, як співвідноситься із загальним
   функціоналом апки і **чи виконує задумане розробником**.

## Рішення користувача (зафіксовані)

| Питання | Рішення |
|---|---|
| Зламана незадекларована фіча | Додатково **SUSPICIOUS** у «Підозрілі» (`[coverage/undeclared-feature]`); вердикт не блокує реліз сама по собі, але впливає як звичайний suspicious |
| Місце у звіті | **Окрема секція** `### Незадекларовані фічі (поза каталогом правил)` після «Спостережень» |
| Сплеш відсутній / статичний / нетематичний | **OBSERVATION** у всіх трьох випадках |

## Архітектурний вибір для coverage-sweep

Розглянуто 3 підходи:

- **A. Agent-stage (обрано)** — новий **Step 5b** у
  `agents/functional-validator.md`. Sweep — це не правило з
  інваріантом, а «друга половина Stage 0»: Stage 0 каже *що апка
  має*, Step 5b — *що апка має понад те, що каталог правил уміє
  перевірити*. Прецедент agent-level логіки вже є (Stage 0).
- B. Rule-файл `meta/undeclared-features.md` — відхилено: не
  інваріант, а sweep; routing-таблиця знає лише 3 секції — виняток в
  агенті знадобився б усе одно; `meta/` за описом — identity-інваріанти.
- C. Гібрид rule + hook — відхилено: дві рухомі частини без виграшу.

---

## Фіча 1 — правило `rules/perf/splash-screen-quality.md`

- **Frontmatter:** `severity: observation`, `category: perf`,
  `since: "2.11.0"`, без `requires-project-type` (універсальне).
- **Інваріант:** апка має сплеш-скрін, який (1) існує, (2) анімований,
  (3) відповідає тематиці гри й заохочує користувача.
- **Як перевірити:**
  1. *Наявність* — каталог відомих механізмів (не exhaustive):
     SplashScreen API (`Theme.SplashScreen`, `installSplashScreen()`),
     кастомний Compose-екран (`Splash*`/`Loader*` route першим у
     NavHost + навігація далі), Lottie (`lottie-compose` +
     `res/raw/*.json`), `AnimationDrawable`/`AnimatedVectorDrawable`,
     відео-сплеш.
  2. *Анімованість* — dataflow: чи стартовий екран містить
     брендований рух (Lottie/AVD/animation-list,
     `rememberInfiniteTransition`, `animate*AsState`, `Animatable`,
     `ObjectAnimator`, відео). Статична картинка + `delay()` або
     голий системний спінер = НЕ анімований сплеш.
  3. *Тематичність* — **judgment call агента** (допустимо, бо
     severity = observation): зіставити асети сплеша (назви
     drawable/raw, шари Lottie-JSON `layers[].nm`, кольори, текст)
     з тематикою апки (app_name, ігрові асети, домен гри).
  4. Емітити **рівно один** finding за пріоритетом:
     відсутній > статичний > нетематичний. Усе гаразд →
     «Перевірені інваріанти».
- **Як доповідати:** 3 шаблони OBSERVATION.
- **Виключення:** через `accepted-deviations` (брендована вимога
  замовника «без сплеша», text-only апки тощо).

## Фіча 2 — coverage-sweep: Step 5b + нова секція звіту

### Step 5b у `agents/functional-validator.md` (після Step 5)

1. **Інвентаризація** функціональних механізмів (читання + трейс):
   - entry-chain (`Application.onCreate` → launcher → перший екран) і
     кожен conditional gate на ньому (ADB/emulator/debugger/root-детект,
     connectivity-гейти, time-гейти);
   - manifest: permissions (додані ТА зняті через `tools:node="remove"`),
     backup-конфіг, exported-компоненти, intent-filters;
   - native: `cpp/`, `jniLibs/*.so`, `System.loadLibrary`;
   - vendored SDK-вихідники замість gradle-залежностей;
   - кастомний IPC: ручний `bindService` + `transact`/`Parcel`, AIDL;
   - мережа повз основний HTTP-клієнт: сирі `Socket`, окремі клієнти;
   - identity-linking: один ідентифікатор у кілька систем
     (push SDK `login`, analytics);
   - build-hardening: R8/minify/shrink, proguard-rules.
2. **Зіставлення:** механізм покритий, якщо БУДЬ-ЯКЕ правило цього
   прогону його перевірило (pass/fail/skip-з-причиною) або Stage 0
   його задетектив. Покрите → не дублювати.
3. **Непокрите → entry** у секцію: назва, `file:line`, що робить
   (1–3 рядки), роль у загальному функціоналі апки, вердикт за
   dataflow: ✅ виконує задумане / ⚠️ не виконує.
4. **⚠️ → додатковий SUSPICIOUS** finding
   `[coverage/undeclared-feature]` у «Підозрілі» (що зламано, чому,
   як виправити). Заглушується через
   `accepted-deviations: coverage/undeclared-feature: <фіча> — <причина>`
   → SUSPICIOUS не емітиться, entry лишається з позначкою `(accepted)`.
5. **НЕ фіча:** UI/DI/navigation-boilerplate, бібліотеки у штатному
   вжитку, все вже покрите правилами. Порожній sweep → `(відсутні)`.

### Нова секція звіту (Step 7), після «Спостережень»

```
### Незадекларовані фічі (поза каталогом правил)

**1. <Назва>**  ✅ виконує задумане | ⚠️ не виконує задумане
  <file>:<line>
  <що робить; роль у загальному функціоналі апки — 1–3 рядки>
```

### `commands/android-review.md`

- Step 6: секція агента протікає у повний звіт автоматично (skeleton
  обгортає весь output) — зміна не потрібна.
- Step 8: новий рядок термінал-summary —
  `**Незадекларовані фічі:** <N> (⚠️ <M>)`.

## Реліз v2.11.0

- `plugin.json`, `marketplace.json` → `2.11.0`.
- CHANGELOG-запис (Added: правило + Step 5b; Changed: agent, command).
- README: рядок про нову секцію звіту + bump версії.

## Поза скоупом

- Динамічна оцінка сплеша (запуск апки, скріншоти) — плагін static-only.
- Автогенерація нових rule-файлів із знайдених фіч — рев'юер вирішує
  сам, що піднімати в правило (`docs/how-to-add-a-rule.md`).

## E2E-перевірка (очікування на Fruit-Game)

- Секція «Незадекларовані фічі» з ~8–10 entries (ADB-гейт,
  Socket:53-гейт, AIDL GAID, vendored referrer, `libvault.so`,
  OneSignal-login(uuid), backup-rules, R8) — кожна з вердиктом.
- OBSERVATION від `perf/splash-screen-quality`, якщо сплеш статичний
  або нетематичний.
- Термінал-summary показує `Незадекларовані фічі: N (⚠️ M)`.
