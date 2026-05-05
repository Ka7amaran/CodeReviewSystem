# Android Review v2.0 — Functional Validator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the plugin from a 21-rule structural validator into a single-agent functional validator covering 8 dataflow rules grounded in the team's actual app contract (`docs/specs/2026-05-05-v2-functional-validator-design.md`).

**Architecture:** One cohesive `functional-validator` sub-agent. Orchestration runs in the slash-command body (top-level Claude has Task; sub-agents do not — proven in v1.5.0). Two slash commands only: `/android-review` (full review) + `/android-review-init` (5-field CLAUDE.md scaffold). Rules are dataflow checks, not grep patterns. Reports are 3-severity (Критичні / Підозрілі / Спостереження) plus a "Перевірені інваріанти" pass list. Output is `.md` only with `archive/` rotation.

**Tech Stack:** Markdown (rule files, agent prompts, command files), YAML frontmatter, JSON (plugin manifest, marketplace), Bash for verification. Targets Android Kotlin/Compose/Hilt projects.

**Source spec:** `/Users/mac/CodeReviewSystem/docs/specs/2026-05-05-v2-functional-validator-design.md`.

---

## File structure (target end state)

```
/Users/mac/CodeReviewSystem/
├── .claude-plugin/
│   ├── plugin.json                              (version 2.0.0)
│   └── marketplace.json                         (version 2.0.0)
├── README.md                                    (unchanged)
├── CHANGELOG.md                                 (new 2.0.0 entry on top)
├── .gitignore                                   (unchanged)
├── commands/
│   ├── android-review.md                        (full rewrite)
│   └── android-review-init.md                   (full rewrite, 5-field scaffold)
├── agents/
│   └── functional-validator.md                  (new, single agent)
├── rules/
│   ├── _schema.md                               (full rewrite)
│   ├── _template.md                             (full rewrite)
│   ├── flow/
│   │   ├── initial-startup-checklist.md
│   │   ├── uuid-persistence.md
│   │   ├── organic-routing-critical.md
│   │   ├── non-organic-post-required.md
│   │   └── redirect-method-correctness.md
│   ├── webview/
│   │   ├── config-completeness.md
│   │   └── activity-fullscreen-orientation.md
│   └── crypto/
│       └── post-data-encoding-pattern.md
├── docs/
│   ├── specs/                                   (specs unchanged; new v2 spec already there)
│   ├── plans/                                   (this plan lives here)
│   ├── project-claude-md-template.md            (full rewrite, 5-field reference)
│   ├── how-to-add-a-rule.md                     (full rewrite, new body sections)
│   └── smoke-test.md                            (full rewrite for v2 expectations)
└── examples/
    ├── good-claude-md-for-project.md            (full rewrite, 5 fields)
    └── claude-md-gitignore.txt                  (unchanged)
```

**Files DELETED:**
- `agents/style-auditor.md`
- `agents/security-auditor.md`
- `agents/obfuscation-auditor.md`
- `commands/android-review-style.md`
- `commands/android-review-security.md`
- `commands/android-review-obfuscation.md`
- `rules/style/` (entire directory, 8 files)
- `rules/security/` (entire directory, 7 files)
- `rules/obfuscation/` (entire directory, 6 files)
- `examples/good-proguard-rules.pro`

---

## Verification model

No automated tests (markdown plugin). Verification is manual smoke-test
on a real Android project at the end (Task 18). Per-task verification
is a `bash` invocation that checks file presence + key markers via
`grep` / `head` / `wc`.

Engineer must `cd /Users/mac/CodeReviewSystem` before running any
commands in this plan unless an absolute path is given.

---

## Task 1: Cleanup — delete v1.x agents, commands, rules, examples

**Files:**
- Delete: `agents/style-auditor.md`
- Delete: `agents/security-auditor.md`
- Delete: `agents/obfuscation-auditor.md`
- Delete: `commands/android-review-style.md`
- Delete: `commands/android-review-security.md`
- Delete: `commands/android-review-obfuscation.md`
- Delete: `rules/style/` (entire directory)
- Delete: `rules/security/` (entire directory)
- Delete: `rules/obfuscation/` (entire directory)
- Delete: `examples/good-proguard-rules.pro`

- [ ] **Step 1: Verify the delete list against current state**

```bash
cd /Users/mac/CodeReviewSystem
ls agents/ commands/ rules/ examples/ | sort
```

Expected output (current v1.5.0 state):
```
agents/:
obfuscation-auditor.md
security-auditor.md
style-auditor.md

commands/:
android-review-init.md
android-review-obfuscation.md
android-review-security.md
android-review-style.md
android-review.md

rules/:
_schema.md
_template.md
obfuscation
security
style

examples/:
claude-md-gitignore.txt
good-claude-md-for-project.md
good-proguard-rules.pro
```

If anything is missing or extra, STOP and inspect — the repo state
diverged from the plan baseline.

- [ ] **Step 2: git rm the v1.x artifacts**

```bash
cd /Users/mac/CodeReviewSystem
git rm agents/style-auditor.md agents/security-auditor.md agents/obfuscation-auditor.md
git rm commands/android-review-style.md commands/android-review-security.md commands/android-review-obfuscation.md
git rm -r rules/style rules/security rules/obfuscation
git rm examples/good-proguard-rules.pro
```

- [ ] **Step 3: Verify only v2.x carryover files remain**

```bash
cd /Users/mac/CodeReviewSystem
ls agents/ commands/ rules/ examples/ | sort
```

Expected:
```
agents/:

commands/:
android-review-init.md
android-review.md

rules/:
_schema.md
_template.md

examples/:
claude-md-gitignore.txt
good-claude-md-for-project.md
```

(`agents/` empty is OK; we recreate in Task 11.)

- [ ] **Step 4: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git commit -m "refactor!: delete v1.x style/security/obfuscation rules, agents, commands

BREAKING: this is the cleanup step before v2.0 functional-validator
rewrite. v1.x stays accessible via git history (tag v1.5.0).

Files deleted:
- agents/{style,security,obfuscation}-auditor.md (3 sub-agents)
- commands/android-review-{style,security,obfuscation}.md (3 specialized commands)
- rules/{style,security,obfuscation}/ (21 rules)
- examples/good-proguard-rules.pro (legacy reference)

Plugin is in a non-working state until subsequent v2.0 tasks land
(new agent, new rules, rewritten commands, version bump)."
```

---

## Task 2: New rule schema + template

**Files:**
- Modify: `rules/_schema.md` (full rewrite)
- Modify: `rules/_template.md` (full rewrite)

- [ ] **Step 1: Rewrite `rules/_schema.md`**

Replace the entire file content with:

```markdown
# Rule file schema (v2.0 — functional)

Every rule lives in `rules/<category>/<rule-id-slug>.md` where `category`
is one of `flow`, `webview`, `crypto`. The filename slug must match the
`id` field after the `/`.

## Frontmatter (5 mandatory + 1 optional fields)

```yaml
---
id: <category>/<slug>                  # e.g. flow/organic-routing-critical
severity: critical | suspicious | observation   # see § Severity below
category: flow | webview | crypto      # duplicates first id segment
applies-to:                            # OPTIONAL hint for the agent's attention
  - <pattern>                          # NOT a hard pre-filter — agent does dataflow tracing
since: "<semver>"                      # plugin version that introduced the rule
requires-project-type: with-attribution | no-attribution   # OPTIONAL; if set, rule auto-skips on non-matching projects
---
```

## Body (6 mandatory sections, each `## Heading`)

1. **`## Інваріант`** — what behavior must hold at runtime. The
   contract the rule defends. 1-3 sentences.
2. **`## Як перевірити`** — dataflow-trace recipe for the agent.
   How to verify the invariant by reading code (which symbols to
   look for, which call chains to follow, which file types to read).
   This is NOT a grep recipe — it's a reasoning recipe.
3. **`## Як виглядає поломка`** — minimal example of the broken
   behavior (Kotlin/XML/JSON snippet).
4. **`## Як виглядає правильно`** — minimal example of correct
   behavior.
5. **`## Як доповідати`** — exact finding template (Ukrainian body
   for human-readable text; rule-id and severity stay English as
   machine-readable tokens).
6. **`## Виключення`** — when the user can silence the rule via
   `accepted-deviations` in `.claude/CLAUDE.md`. Use the literal
   text `Жодних` if the rule cannot be silenced (reserved for
   `flow/organic-routing-critical`).

## Severity scheme

- **`critical`** — broken invariant causes runtime issue or violates
  the user-defined contract; report verdict becomes `🔴 НЕ ГОТОВО`.
- **`suspicious`** — non-blocking heuristic, worth a glance.
- **`observation`** — informational, never blocks.

## Categories

- **`flow/`** — application-startup and runtime behavior (UUID,
  push init, attribution, routing, redirect method).
- **`webview/`** — WebView/CustomTabs configuration and host
  Activity requirements.
- **`crypto/`** — POST-data encoding pattern (file paths NOT
  pinned; only the pattern).

Style/security/obfuscation categories from v1.x are deleted —
they don't map to functional flows.

## How the agent applies rules

1. Discover all `*.md` files in `rules/<category>/` (skip files
   starting with `_`).
2. Read project's `.claude/CLAUDE.md` for `project-type` and
   `accepted-deviations` (and `redirect-method` for the redirect
   rule).
3. For each rule:
   - If `requires-project-type` is set and doesn't match → skip,
     surface under "Пропущені перевірки" with reason
     "project-type: <X> required, current: <Y>".
   - If `id` is in `accepted-deviations` AND the rule's
     `## Виключення` allows suppression → skip, surface under
     "Пропущені перевірки" with the user's verbatim reason.
   - Otherwise → consult context7 MCP for currency
     (`mcp__plugin_context7_context7__query-docs`) before flagging.
   - Apply the `## Як перевірити` recipe via dataflow tracing.
   - For each violation → emit a finding using the
     `## Як доповідати` template (Ukrainian body).
   - For each rule that PASSED → list under "Перевірені інваріанти".
4. Group findings by emitted severity (`critical` →
   `🔴 Критичні баги функціональної логіки`, `suspicious` →
   `⚠️ Підозрілі патерни`, `observation` → `ℹ️ Спостереження`).
```

- [ ] **Step 2: Rewrite `rules/_template.md`**

Replace the entire file content with:

```markdown
---
id: <category>/<slug>
severity: suspicious
category: <category>
applies-to:
  - <hint-pattern>
since: "2.0.0"
requires-project-type: with-attribution
---

# <Human-readable rule title>

## Інваріант

(1-3 sentences: what behavior must hold at runtime.)

## Як перевірити

(Dataflow-trace recipe for the agent. Describe which symbols / call
chains / file types to inspect. NOT a grep recipe.)

1. (First step of reasoning.)
2. (Second step.)
3. (...)

## Як виглядає поломка

```kotlin
(minimal example of the broken behavior)
```

## Як виглядає правильно

```kotlin
(minimal example of correct behavior)
```

## Як доповідати

```
[<rule-id>] <SEVERITY-IN-CAPS>
  <file>:<line>          (or <file> if no line, or "(decentralized — see notes)" if no specific file)
  <one-sentence Ukrainian description of the violation>
  Як виправити: <one-sentence Ukrainian fix instruction>.
  Див.: <reference URL or examples/path>.
```

## Виключення

(When suppression via `accepted-deviations` is allowed. Use literal
`Жодних` if the rule cannot be silenced.)
```

- [ ] **Step 3: Verify**

```bash
cd /Users/mac/CodeReviewSystem
head -2 rules/_schema.md | grep -q "^# Rule file schema (v2.0 — functional)$" && \
  head -10 rules/_template.md | grep -q "^---$" && \
  grep -q "## Інваріант" rules/_template.md && echo OK
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add rules/_schema.md rules/_template.md
git commit -m "feat(rules)!: rewrite schema + template for v2.0 functional model

New 6-section body (Інваріант / Як перевірити / Як виглядає поломка /
Як виглядає правильно / Як доповідати / Виключення). New severity
scheme (critical/suspicious/observation). New category set (flow/
webview/crypto). New optional 'requires-project-type' frontmatter
field for auto-skipping rules on no-attribution projects."
```

---

## Task 3: rules/flow/initial-startup-checklist.md

**Files:**
- Create: `rules/flow/initial-startup-checklist.md`

- [ ] **Step 1: Create the directory**

```bash
cd /Users/mac/CodeReviewSystem
mkdir -p rules/flow
```

- [ ] **Step 2: Write the rule**

Write `/Users/mac/CodeReviewSystem/rules/flow/initial-startup-checklist.md` with this exact content:

````markdown
---
id: flow/initial-startup-checklist
severity: suspicious
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
requires-project-type: with-attribution
---

# Початкові дії після запуску апки виконуються (всі 6 кроків)

## Інваріант

Для `with-attribution` проєктів усі 6 початкових дій мають
відбуватися при запуску апки (у будь-якому порядку, у будь-якому
місці коду — не обов'язково на splash):

1. Отримання або генерація UUID.
2. Ініціалізація push-сервісу (OneSignal або еквівалент) з login(uuid).
3. Отримання Install Referrer (будь-яким SDK).
4. Отримання adId (будь-яким способом).
5. Запит на бекенд-домен.
6. Подальший роутинг (WebView/CustomTabs або гра).

## Як перевірити

Це dataflow-перевірка, не grep. Агент має простежити стартову
послідовність викликів від точки входу (`Application.onCreate`,
launcher Activity's `onCreate`, перший Composable у NavGraph) і
переконатись, що до моменту першого UI-рендеру виконано усі 6 дій.

1. Знайти точку входу: `class * : Application()` із
   `@HiltAndroidApp`/`AndroidEntryPoint` АБО launcher Activity з
   `<intent-filter>` MAIN/LAUNCHER.
2. Слідкувати за стартовим dataflow: які класи інстанціюються,
   які корутини запускаються у `onCreate` / `LaunchedEffect` /
   `init` блоках.
3. Для кожного з 6 кроків знайти **факт виконання** (без вимог
   до конкретного SDK):
   - UUID: будь-який вираз, що зчитує/пише `uuid`/`user_id`/
     `device_id` із persistence layer + умовна генерація.
   - Push init: будь-який виклик схожий на
     `OneSignal.initWithContext(...)` або еквівалент.
   - Install Referrer: будь-який виклик до Install Referrer Library
     АБО SDK типу AppsFlyer/Tenjin/Adjust.
   - adId: будь-який виклик до `AdvertisingIdClient` АБО
     еквівалент SDK.
   - Domain request: будь-який HTTP-виклик до URL із
     `backend-domain` (з CLAUDE.md).
   - Routing: видимий decision-point що веде або у Game-екран,
     або у WebView/CustomTabs.
4. Кожен пропущений крок = окрема знахідка `suspicious`-severity.
   Чотири і більше пропущених кроків поспіль → промоут до
   `critical` (це не просто пропуск окремої дії, це відсутність
   стартового флоу взагалі).

## Як виглядає поломка

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // нічого зі стартового flow не виконується
    }
}

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { GameScreen() }   // одразу гра, без attribution
    }
}
```

## Як виглядає правильно

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        OneSignal.initWithContext(this, BuildConfig.ONESIGNAL_APP_ID)
    }
}

class StartupRouter @Inject constructor(
    private val uuidStore: UuidStore,
    private val referrerClient: InstallReferrerClient,
    private val adIdClient: AdIdClient,
    private val backend: BackendApi,
) {
    suspend fun startup(): RouteDecision {
        val uuid = uuidStore.getOrCreate()
        OneSignal.login(uuid)
        val ref = referrerClient.fetch()
        val adId = adIdClient.fetch()
        val response = backend.notify(uuid, ref, adId)
        return response.route
    }
}
```

(Конкретні класи/SDK не важливі — важливо що всі 6 дій присутні
і досяжні з точки входу.)

## Як доповідати

```
[flow/initial-startup-checklist] SUSPICIOUS
  <file>:<line>   (точка входу або найближче місце де крок мав би відбутися)
  Початковий флоу не містить кроку "<step-name>" — <конкретне пояснення dataflow>.
  Як виправити: додайте відповідний виклик у стартову послідовність до першого UI-рендеру.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.1
```

## Виключення

Дозволено через `accepted-deviations` для конкретних кроків, якщо
проєкт усвідомлено пропускає (наприклад, push-нотифікації вимкнено
бізнес-рішенням). Обґрунтування обов'язкове.
````

- [ ] **Step 3: Verify**

```bash
cd /Users/mac/CodeReviewSystem
head -1 rules/flow/initial-startup-checklist.md | grep -q "^---$" && \
  grep -q "^id: flow/initial-startup-checklist$" rules/flow/initial-startup-checklist.md && \
  grep -q "## Інваріант" rules/flow/initial-startup-checklist.md && echo OK
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add rules/flow/initial-startup-checklist.md
git commit -m "feat(rules): add flow/initial-startup-checklist (v2.0)"
```

---

## Task 4: rules/flow/uuid-persistence.md

**Files:**
- Create: `rules/flow/uuid-persistence.md`

- [ ] **Step 1: Write the rule**

Write `/Users/mac/CodeReviewSystem/rules/flow/uuid-persistence.md`:

````markdown
---
id: flow/uuid-persistence
severity: suspicious
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
requires-project-type: with-attribution
---

# UUID зберігається між сесіями і переюзується

## Інваріант

Якщо при першому запуску згенерувано UUID, при наступному запуску
той самий UUID має бути прочитаний із persistence (а не згенерований
заново). Storage-механізм не важливий: SharedPreferences,
EncryptedSharedPreferences, Room, DataStore, Firebase, будь-яке
локальне або хмарне сховище.

## Як перевірити

1. Знайти точку, де UUID генерується — будь-який виклик типу
   `UUID.randomUUID()`, `SecureRandom`, або власної generator-функції,
   результат якої присвоюється змінній з ім'ям, що містить `uuid`/
   `user_id`/`device_id`.
2. Перевірити, що згенероване значення **зберігається** одразу
   після генерації — виклик `prefs.edit().putString(...)`,
   `dataStore.edit { ... }`, `dao.insert(...)`, тощо.
3. Знайти точку, де UUID **читається** при старті — виклик
   `prefs.getString(key, null)`, `dataStore.data.first()`,
   `dao.get()`, тощо.
4. Перевірити, що генерація відбувається **тільки якщо читання
   повернуло null/empty** (тобто паттерн "read-or-create").
5. Перевірити, що прочитаний UUID передається далі (у push login,
   у POST до бекенду, у WebView URL).

Якщо генерація відбувається безумовно (без read-check) — UUID
переписується кожного запуску, attribution ламається. Це **critical**.

Якщо UUID читається але потім ніде не використовується — це теж
**critical** (фактично передається null до бекенду).

## Як виглядає поломка

```kotlin
class UserStorage(private val prefs: SharedPreferences) {
    fun getUuid(): String {
        val uuid = UUID.randomUUID().toString()   // ❌ генерується щоразу
        prefs.edit().putString("uuid", uuid).apply()
        return uuid
    }
}
```

## Як виглядає правильно

```kotlin
class UserStorage(private val prefs: SharedPreferences) {
    fun getOrCreateUuid(): String {
        return prefs.getString("uuid", null) ?: run {
            val newUuid = UUID.randomUUID().toString()
            prefs.edit().putString("uuid", newUuid).apply()
            newUuid
        }
    }
}
```

## Як доповідати

```
[flow/uuid-persistence] CRITICAL    (або SUSPICIOUS, залежно від проблеми)
  <file>:<line>
  UUID <генерується безумовно при кожному старті | читається, але далі не використовується | відсутній read-or-create патерн>.
  Як виправити: реалізуйте паттерн "якщо UUID існує → переюз; якщо ні → згенеруй і збережи". Storage будь-який.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.2
```

## Виключення

Жодних. Persistence UUID між сесіями — фундаментальна вимога
attribution-флоу. Якщо вона не виконується — апка ламає бізнес-логіку
і це критичний баг.
````

- [ ] **Step 2: Verify**

```bash
cd /Users/mac/CodeReviewSystem
grep -q "^id: flow/uuid-persistence$" rules/flow/uuid-persistence.md && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add rules/flow/uuid-persistence.md
git commit -m "feat(rules): add flow/uuid-persistence (v2.0)"
```

---

## Task 5: rules/flow/organic-routing-critical.md (THE critical rule)

**Files:**
- Create: `rules/flow/organic-routing-critical.md`

- [ ] **Step 1: Write the rule**

Write `/Users/mac/CodeReviewSystem/rules/flow/organic-routing-critical.md`:

````markdown
---
id: flow/organic-routing-critical
severity: critical
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
requires-project-type: with-attribution
---

# Organic-користувач теж відкриває WebView/CustomTabs

## Інваріант

Для **всіх** користувачів (organic AND non-organic):
- Запит на бекенд-домен виконується.
- UUID передається.
- WebView/CustomTabs відкривається.

Для **тільки non-organic**:
- Виконується POST з `{uuid, ref, adId}`.

Organic визначається за referrer'ом, що містить
`utm_source=google-play&utm_medium=organic`.

**Якщо organic-користувач йде одразу в гру, минаючи WebView — це
КРИТИЧНИЙ БАГ.** Це найважливіший інваріант плагіна.

## Як перевірити

1. Знайти точку, де читається referrer (з §3.4 spec'у — будь-який
   спосіб отримання Install Referrer).
2. Знайти умовний branch після того, як referrer прочитаний —
   `if (ref.contains("utm_medium=organic"))` або еквівалент.
3. **Перевірити дві гілки:**
   - **Branch для organic** має призводити до запуску WebView/CustomTabs
     (виклик `webView.loadUrl(...)`, `CustomTabsIntent.launchUrl(...)`,
     навігація на WebView-екран). Якщо ця гілка призводить до
     навігації на гру (Game-екран, без проходження WebView) →
     **CRITICAL FINDING**.
   - **Branch для non-organic** має містити POST-виклик до
     backend-домену з тілом `{uuid, ref, adId}` АБО переадресацію
     на WebView (POST може бути перед WebView). Якщо POST
     відсутній — це теж critical, але це покривається окремим
     правилом `flow/non-organic-post-required`.
4. Якщо умовний branch взагалі відсутній (нема перевірки на
   organic) і апка просто завжди йде в гру → CRITICAL.

Це найскладніша dataflow-перевірка плагіна. Агент має простежити
повну стартову послідовність і знайти **рішення routing'а**, а не
просто наявність окремих викликів.

## Як виглядає поломка

```kotlin
class StartupRouter {
    suspend fun decide(): Route {
        val ref = referrerClient.fetch()
        return if (ref.contains("utm_medium=organic")) {
            Route.Game            // ❌ КРИТИЧНИЙ БАГ — organic минає WebView
        } else {
            Route.WebView(uuid)
        }
    }
}
```

## Як виглядає правильно

```kotlin
class StartupRouter {
    suspend fun decide(): Route {
        val ref = referrerClient.fetch()
        val isOrganic = ref.contains("utm_source=google-play&utm_medium=organic")
        if (!isOrganic) {
            backend.post(uuid, ref, adId)   // POST тільки для non-organic
        }
        return Route.WebView(uuid)           // ✅ WebView для всіх
    }
}
```

## Як доповідати

```
[flow/organic-routing-critical] CRITICAL
  <file>:<line>   (точка routing-рішення)
  Organic-користувачі направляються одразу в гру, минаючи WebView/CustomTabs. Це порушує контракт §3.6 (WebView відкривається для всіх користувачів незалежно від organic-статусу).
  Як виправити: WebView/CustomTabs має відкриватися безумовно для всіх. Єдина різниця для non-organic — додатковий POST на бекенд-домен з `{uuid, ref, adId}` ПЕРЕД відкриттям WebView (або паралельно).
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.6
```

## Виключення

Жодних. Це визначальний контракт продукту — без виконання цього
інваріанту бізнес-метрики attribution руйнуються. Не вимикається
через `accepted-deviations`.
````

- [ ] **Step 2: Verify**

```bash
cd /Users/mac/CodeReviewSystem
grep -q "^severity: critical$" rules/flow/organic-routing-critical.md && \
  grep -q "Жодних" rules/flow/organic-routing-critical.md && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add rules/flow/organic-routing-critical.md
git commit -m "feat(rules): add flow/organic-routing-critical (the §3.6 contract — most important rule of v2.0)"
```

---

## Task 6: rules/flow/non-organic-post-required.md

**Files:**
- Create: `rules/flow/non-organic-post-required.md`

- [ ] **Step 1: Write the rule**

Write `/Users/mac/CodeReviewSystem/rules/flow/non-organic-post-required.md`:

````markdown
---
id: flow/non-organic-post-required
severity: suspicious
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
requires-project-type: with-attribution
---

# Non-organic користувачі відправляють POST на бекенд

## Інваріант

Для non-organic користувачів (referrer не містить
`utm_medium=organic`) має виконатись HTTP POST на `backend-domain`
з тілом `{uuid, ref, adId}` (точні ключі узгоджуються з бекендом —
важлива наявність трьох значень).

User-Agent цього POST'а — кастомний, не дефолтний від Ktor/OkHttp.
Стандартний підхід команди: `System.getProperty("http.agent") ?:
"Android"`.

## Як перевірити

1. Знайти branch, що виконується для non-organic (`!isOrganic` або
   еквівалент після перевірки referrer'а).
2. У цьому branch'і знайти HTTP POST виклик — будь-який клієнт
   (Ktor `client.post`, OkHttp `Request.Builder().post(...)`,
   Retrofit `@POST`) до URL що збігається з `backend-domain` із
   CLAUDE.md.
3. Перевірити що body запиту містить:
   - значення UUID (із §3.2),
   - referrer string,
   - adId.
4. Перевірити що User-Agent виставлений явно (не дефолтний). Якщо
   UA не виставлений — окремий finding `suspicious`.

Якщо POST не існує для non-organic branch'а — критичний баг
(attribution не працює). Якщо POST існує але не містить одного з
трьох значень — `suspicious`.

## Як виглядає поломка

```kotlin
suspend fun startup() {
    val ref = referrerClient.fetch()
    val isOrganic = ref.contains("utm_medium=organic")
    if (!isOrganic) {
        // ❌ POST відсутній — adId і ref не передаються на бекенд
    }
    openWebView(uuid)
}
```

## Як виглядає правильно

```kotlin
suspend fun startup() {
    val ref = referrerClient.fetch()
    val isOrganic = ref.contains("utm_medium=organic")
    if (!isOrganic) {
        val adId = adIdClient.fetch()
        httpClient.post("https://domain.store/track") {
            header("User-Agent", System.getProperty("http.agent") ?: "Android")
            setBody(mapOf("uuid" to uuid, "ref" to ref, "adId" to adId))
        }
    }
    openWebView(uuid)
}
```

## Як доповідати

```
[flow/non-organic-post-required] SUSPICIOUS    (CRITICAL якщо POST відсутній взагалі)
  <file>:<line>
  Non-organic branch не виконує POST на backend-домен з {uuid, ref, adId} | POST виконується, але body не містить <value> | User-Agent не виставлений явно.
  Як виправити: додайте POST-виклик у non-organic branch з тілом, що містить uuid, ref, adId. User-Agent — `System.getProperty("http.agent") ?: "Android"`.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.6
```

## Виключення

Дозволено через `accepted-deviations`, якщо backend-флоу вимагає
іншу схему (наприклад, batch-POST через окремий сервіс). Обґрунтування
обов'язкове.
````

- [ ] **Step 2: Verify**

```bash
cd /Users/mac/CodeReviewSystem
grep -q "^id: flow/non-organic-post-required$" rules/flow/non-organic-post-required.md && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add rules/flow/non-organic-post-required.md
git commit -m "feat(rules): add flow/non-organic-post-required (v2.0)"
```

---

## Task 7: rules/flow/redirect-method-correctness.md

**Files:**
- Create: `rules/flow/redirect-method-correctness.md`

- [ ] **Step 1: Write the rule**

Write `/Users/mac/CodeReviewSystem/rules/flow/redirect-method-correctness.md`:

````markdown
---
id: flow/redirect-method-correctness
severity: suspicious
category: flow
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
requires-project-type: with-attribution
---

# Метод переходу Privacy Policy → game реалізовано коректно

## Інваріант

Перехід із Privacy Policy у гру виконується через **один із трьох
дозволених методів**, обраний у CLAUDE.md `redirect-method`:

- **7.1 webMessageListener** — `WebViewCompat.addWebMessageListener`
  з обмеженням origin'у через `allowedOriginRules`. Web сторона
  надсилає через `appBridge.postMessage(...)`. Android слухає, валідує
  origin, парсить команду.
- **7.2 consoleLog** — `WebChromeClient.onConsoleMessage()` парсить
  повідомлення вигляду `APP_ACTION: GO_GAME`.
- **7.3 shouldOverrideUrlLoading** — Privacy Policy визначається за
  ознакою "не виклинуто `shouldOverrideUrlLoading` до `onPageStarted`".

Плагін перевіряє коректність **тільки** методу із CLAUDE.md, не
шукає всі.

## Як перевірити

1. Прочитати `redirect-method` з `.claude/CLAUDE.md`. Якщо порожнє і
   `landing-mechanism` = `webview` → finding `suspicious` "redirect-method
   не задекларовано". Пропустити решту перевірки.
2. Якщо `landing-mechanism` = `none` або `custom-tabs` — пропустити правило
   повністю (Skipped rules).
3. Залежно від `redirect-method`:
   - **7.1**: знайти виклик `WebViewCompat.addWebMessageListener(...)`.
     Перевірити, що `allowedOriginRules` непорожній і не містить
     wildcard `*`. Перевірити, що `WebMessageListener.onPostMessage`
     валідує `sourceOrigin` і `isMainFrame`.
   - **7.2**: знайти override `WebChromeClient.onConsoleMessage`.
     Перевірити, що тіло парсить очікуваний префікс
     (наприклад, `APP_ACTION:`).
   - **7.3**: знайти override `WebViewClient.shouldOverrideUrlLoading`
     і `onPageStarted`. Перевірити, що логіка визначає Privacy Policy
     за відсутністю `shouldOverrideUrlLoading` до `onPageStarted`.
4. Якщо очікуваний метод не знайдений — `suspicious`.
5. Якщо знайдений, але без валідації origin (для 7.1) → `critical`
   (security issue).

## Як виглядає поломка (приклад для 7.1)

```kotlin
WebViewCompat.addWebMessageListener(
    webView,
    "appBridge",
    setOf("*"),                         // ❌ wildcard origin
    object : WebViewCompat.WebMessageListener {
        override fun onPostMessage(
            view: WebView,
            message: WebMessageCompat,
            sourceOrigin: Uri,
            isMainFrame: Boolean,
            replyProxy: JavaScriptReplyProxy
        ) {
            navigateToGame()             // ❌ без перевірки origin/frame
        }
    }
)
```

## Як виглядає правильно (приклад для 7.1)

```kotlin
val allowedOrigins = setOf("https://domain.store")

WebViewCompat.addWebMessageListener(
    webView,
    "appBridge",
    allowedOrigins,
    object : WebViewCompat.WebMessageListener {
        override fun onPostMessage(
            view: WebView,
            message: WebMessageCompat,
            sourceOrigin: Uri,
            isMainFrame: Boolean,
            replyProxy: JavaScriptReplyProxy
        ) {
            if (sourceOrigin.toString() != "https://domain.store") return
            if (!isMainFrame) return
            if (message.data == "GO_GAME") navigateToGame()
        }
    }
)
```

## Як доповідати

```
[flow/redirect-method-correctness] SUSPICIOUS    (CRITICAL якщо origin не валідується для 7.1)
  <file>:<line>
  Метод <7.1 webMessageListener | 7.2 consoleLog | 7.3 shouldOverrideUrlLoading> <не знайдено | реалізовано без валідації origin/frame | wildcard в allowedOriginRules>.
  Як виправити: <specific guidance per method, see §3.7 спецификації>.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.7
```

## Виключення

Дозволено через `accepted-deviations`, якщо команда тестує
експериментальний метод поза 7.1/7.2/7.3 (наприклад, 7.4 onPageFinished).
Обґрунтування обов'язкове.
````

- [ ] **Step 2: Verify**

```bash
cd /Users/mac/CodeReviewSystem
grep -q "^id: flow/redirect-method-correctness$" rules/flow/redirect-method-correctness.md && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add rules/flow/redirect-method-correctness.md
git commit -m "feat(rules): add flow/redirect-method-correctness (verifies only the method declared in CLAUDE.md)"
```

---

## Task 8: rules/webview/config-completeness.md

**Files:**
- Create: `rules/webview/config-completeness.md`

- [ ] **Step 1: Create directory and write the rule**

```bash
cd /Users/mac/CodeReviewSystem
mkdir -p rules/webview
```

Write `/Users/mac/CodeReviewSystem/rules/webview/config-completeness.md`:

````markdown
---
id: webview/config-completeness
severity: suspicious
category: webview
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
---

# WebView має повний канонічний preset налаштувань

## Інваріант

Якщо у проєкті використовується WebView (`landing-mechanism = webview`),
кожен WebView-instance має містити канонічний preset налаштувань
команди (§3.9 spec'у):

- `mixedContentMode = 0`
- `javaScriptEnabled = true`
- `domStorageEnabled = true`
- `databaseEnabled = true`
- `loadsImagesAutomatically = true`
- `useWideViewPort = true`
- `allowFileAccess = true`
- `javaScriptCanOpenWindowsAutomatically = true`
- `loadWithOverviewMode = true`
- `allowContentAccess = true`
- `setSupportMultipleWindows(true)`
- `builtInZoomControls = true` + `displayZoomControls = false`
- `cacheMode = LOAD_DEFAULT`
- `setLayerType(LAYER_TYPE_HARDWARE, null)`
- `importantForAutofill = IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS` (API 26+)
- `CookieManager.setAcceptCookie(true)` + `setAcceptThirdPartyCookies(webView, true)`
- `webViewClient` встановлений
- `webChromeClient` встановлений (з `onShowFileChooser`,
  `onPermissionRequest`, `onShowCustomView`, `onConsoleMessage` за
  потребою)
- `setDownloadListener` встановлений

## Як перевірити

1. Знайти кожне створення WebView-instance: `WebView(context)`,
   `findViewById<WebView>(...)`, `AndroidView { factory = { WebView(it) } }`.
2. Для кожного WebView у тому самому файлі/функції перевірити
   присутність всіх settings із preset'у.
3. Кожна відсутня налаштування — окремий finding `suspicious`.
4. Опціональні налаштування (Google Sign-In support, deep-link
   handling для Telegram/Instagram/TikTok) — НЕ flag, але якщо
   присутні і виглядають зламаними (наприклад, regex для deep-link
   очевидно неправильний) — `observation`.

## Як виглядає поломка

```kotlin
val webView = WebView(context)
webView.loadUrl(url)
// ❌ нічого не налаштовано
```

## Як виглядає правильно

```kotlin
val webView = WebView(context).apply {
    layoutParams = LayoutParams(MATCH_PARENT, MATCH_PARENT)
    CookieManager.getInstance().setAcceptCookie(true)
    CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
    isSaveEnabled = true
    isFocusable = true
    isFocusableInTouchMode = true
    setLayerType(LAYER_TYPE_HARDWARE, null)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        importantForAutofill = IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
    }
    settings.apply {
        mixedContentMode = 0
        javaScriptEnabled = true
        domStorageEnabled = true
        databaseEnabled = true
        loadsImagesAutomatically = true
        useWideViewPort = true
        allowFileAccess = true
        javaScriptCanOpenWindowsAutomatically = true
        loadWithOverviewMode = true
        allowContentAccess = true
        setSupportMultipleWindows(true)
        builtInZoomControls = true
        displayZoomControls = false
        cacheMode = WebSettings.LOAD_DEFAULT
    }
    webViewClient = myWebClient
    webChromeClient = myChromeClient
    setDownloadListener { url, _, _, _, _ -> startDownload(url) }
}
```

## Як доповідати

```
[webview/config-completeness] SUSPICIOUS
  <file>:<line>
  WebView не має налаштування "<missing-setting>" — це може зламати <auth flow | file upload | fullscreen video | cookies | deep-link>.
  Як виправити: додайте `<specific setting line>` у блок налаштування WebView.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.9
```

## Виключення

Дозволено через `accepted-deviations`, якщо WebView читає виключно
read-only сторінку без auth/upload/cookies (рідкісний випадок).
Обґрунтування обов'язкове — поясніть, який саме flow обмежений.
````

- [ ] **Step 2: Verify**

```bash
cd /Users/mac/CodeReviewSystem
grep -q "^id: webview/config-completeness$" rules/webview/config-completeness.md && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add rules/webview/config-completeness.md
git commit -m "feat(rules): add webview/config-completeness (canonical preset from §3.9)"
```

---

## Task 9: rules/webview/activity-fullscreen-orientation.md

**Files:**
- Create: `rules/webview/activity-fullscreen-orientation.md`

- [ ] **Step 1: Write the rule**

Write `/Users/mac/CodeReviewSystem/rules/webview/activity-fullscreen-orientation.md`:

````markdown
---
id: webview/activity-fullscreen-orientation
severity: suspicious
category: webview
applies-to:
  - app/src/main/AndroidManifest.xml
  - app/src/main/java/**/*.kt
since: "2.0.0"
---

# Activity з WebView/CustomTabs: повноекранний + вільне обертання + видимий top bar

## Інваріант

Activity, що містить WebView або відкриває CustomTabs, має:
- **Вільне обертання** (без блокування orientation у portrait/landscape).
- **Повноекранний режим** без винятків.
- **Top status bar видимий завжди** (індикатори батареї, мережі —
  не приховані).
- Системні навігаційні кнопки — або статичні+видимі, або динамічні
  через свайп. Не блокувати.

## Як перевірити

1. Знайти Activity, що містить WebView (з §3.9 dataflow trace) або
   викликає `CustomTabsIntent.launchUrl(...)`.
2. У `AndroidManifest.xml` для цієї Activity:
   - Атрибут `android:screenOrientation` має бути або **відсутнім**,
     або одним із: `unspecified`, `fullSensor`, `user`,
     `userLandscape`, `userPortrait`, `sensorLandscape`,
     `sensorPortrait`. Не `portrait`/`landscape` (фіксована).
3. У коді Activity / Compose:
   - `WindowInsetsControllerCompat.systemBarsBehavior` НЕ має
     приховувати top status bar (тобто не
     `BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE` з прихованим
     `WindowInsetsCompat.Type.statusBars()`).
   - `setDecorFitsSystemWindows(false)` + `WindowInsetsControllerCompat`
     — OK для повноекранного UI, але statusBars() мають лишатись
     `show()`.
4. Кожне порушення — окремий finding `suspicious`.

## Як виглядає поломка

```xml
<activity
    android:name=".WebViewActivity"
    android:screenOrientation="portrait"               <!-- ❌ фіксована -->
    android:theme="@style/Theme.AppCompat.NoActionBar.Fullscreen" />
```

```kotlin
WindowInsetsControllerCompat(window, window.decorView).apply {
    hide(WindowInsetsCompat.Type.statusBars())          // ❌ прихований top bar
    systemBarsBehavior = BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
}
```

## Як виглядає правильно

```xml
<activity
    android:name=".WebViewActivity"
    android:screenOrientation="unspecified"             <!-- ✅ вільне обертання -->
    android:theme="@style/Theme.AppCompat.NoActionBar" />
```

```kotlin
WindowCompat.setDecorFitsSystemWindows(window, false)
WindowInsetsControllerCompat(window, window.decorView).apply {
    show(WindowInsetsCompat.Type.statusBars())          // ✅ top bar видимий
    systemBarsBehavior = BEHAVIOR_DEFAULT
}
```

## Як доповідати

```
[webview/activity-fullscreen-orientation] SUSPICIOUS
  <file>:<line>
  Activity з WebView/CustomTabs <має фіксовану orientation | приховує top status bar | блокує навігаційні кнопки>.
  Як виправити: <specific guidance>.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.8
```

## Виключення

Жодних для top status bar — він має бути видимим завжди (контракт
§3.8). Дозволено через `accepted-deviations` для фіксованої orientation,
якщо проєкт навмисно так налаштований (наприклад, специфічний layout
вимагає portrait). Обґрунтування обов'язкове.
````

- [ ] **Step 2: Verify**

```bash
cd /Users/mac/CodeReviewSystem
grep -q "^id: webview/activity-fullscreen-orientation$" rules/webview/activity-fullscreen-orientation.md && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add rules/webview/activity-fullscreen-orientation.md
git commit -m "feat(rules): add webview/activity-fullscreen-orientation (§3.8 contract)"
```

---

## Task 10: rules/crypto/post-data-encoding-pattern.md

**Files:**
- Create: `rules/crypto/post-data-encoding-pattern.md`

- [ ] **Step 1: Create directory and write the rule**

```bash
cd /Users/mac/CodeReviewSystem
mkdir -p rules/crypto
```

Write `/Users/mac/CodeReviewSystem/rules/crypto/post-data-encoding-pattern.md`:

````markdown
---
id: crypto/post-data-encoding-pattern
severity: suspicious
category: crypto
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "2.0.0"
requires-project-type: with-attribution
---

# Дані POST-запиту проходять через єдиний патерн кодування

## Інваріант

Дані, що відправляються в POST на `backend-domain` (з §3.6), мають
проходити через єдиний патерн кодування проєкту (зазвичай
AES + Base64 URL-safe, але точний алгоритм не важливий — важливо що
**один і той самий патерн** використовується послідовно).

Файли і класи, що реалізують кодування, можуть бути будь-де у
кодовій базі — плагін НЕ привʼязується до шляхів типу
`*.crypto.*` чи `*.settings.*`.

## Як перевірити

1. Знайти POST-виклик до backend-домену (з §3.6 dataflow).
2. Простежити origin тіла запиту: яка функція готує body? Який
   ланцюг трансформацій застосовується до raw values UUID/ref/adId
   до моменту виклику HTTP?
3. Перевірити, що цей ланцюг містить **криптографічну операцію**
   (виклики `Cipher`, `Mac`, `MessageDigest`, або
   еквіваленти AES/Base64/HMAC через будь-яку бібліотеку).
4. Якщо raw values напряму серіалізуються в JSON без кодування —
   finding `suspicious` (можливо проєкт навмисно so, але треба
   переглянути).
5. Якщо знайдено кілька різних кодувальних патернів у різних
   POST-викликах — finding `suspicious` (несумісність).

## Як виглядає поломка

```kotlin
suspend fun postAttribution(uuid: String, ref: String, adId: String) {
    httpClient.post("https://domain.store/track") {
        setBody(mapOf("uuid" to uuid, "ref" to ref, "adId" to adId))
        // ❌ Plain JSON, без кодування. Бекенд очікує encoded payload.
    }
}
```

## Як виглядає правильно

```kotlin
class PayloadEncoder(private val key: ByteArray) {
    fun encode(uuid: String, ref: String, adId: String): String {
        val plain = """{"uuid":"$uuid","ref":"$ref","adId":"$adId"}"""
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding").apply {
            init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), IvParameterSpec(iv))
        }
        val encrypted = cipher.doFinal(plain.toByteArray())
        return Base64.encodeToString(encrypted, Base64.URL_SAFE or Base64.NO_WRAP)
    }
}

suspend fun postAttribution(uuid: String, ref: String, adId: String) {
    val payload = encoder.encode(uuid, ref, adId)
    httpClient.post("https://domain.store/track") {
        setBody(mapOf("payload" to payload))    // ✅ encoded
    }
}
```

## Як доповідати

```
[crypto/post-data-encoding-pattern] SUSPICIOUS
  <file>:<line>   (POST-виклик або encoder-функція)
  POST на backend-домен надсилає <plain-text body | дані з різними патернами кодування у різних викликах>.
  Як виправити: проведіть UUID/ref/adId через єдиний кодувальний патерн перед відправкою. Конкретний алгоритм/бібліотека не важливі — важливо що один і той самий патерн усюди.
  Див.: docs/specs/2026-05-05-v2-functional-validator-design.md §3.10
```

## Виключення

Дозволено через `accepted-deviations`, якщо бекенд навмисно
очікує plain-JSON або інший формат. Обґрунтування обов'язкове —
поясніть, чому кодування не використовується.
````

- [ ] **Step 2: Verify**

```bash
cd /Users/mac/CodeReviewSystem
grep -q "^id: crypto/post-data-encoding-pattern$" rules/crypto/post-data-encoding-pattern.md && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add rules/crypto/post-data-encoding-pattern.md
git commit -m "feat(rules): add crypto/post-data-encoding-pattern (no path pinning)"
```

---

## Task 11: New `agents/functional-validator.md`

**Files:**
- Create: `agents/functional-validator.md`

- [ ] **Step 1: Write the agent**

Write `/Users/mac/CodeReviewSystem/agents/functional-validator.md`:

````markdown
---
name: functional-validator
description: Functional Android validator. Reads rules from rules/{flow,webview,crypto}/, performs dataflow tracing on the project, returns a structured Ukrainian-language markdown report. Read-only.
tools: [Read, Glob, Grep, mcp__plugin_context7_context7__query-docs, mcp__plugin_context7_context7__resolve-library-id]
---

You are **functional-validator**, the single audit sub-agent of the
android-review plugin v2.0.

## Your job

Apply every rule in `rules/{flow,webview,crypto}/` to the Android
project at the current working directory and produce one markdown
report. The verification is **functional**: trace dataflow, verify
behavior contracts, do NOT pin to file paths/class names/library
versions.

## Important context (provided by the caller)

When dispatched, you receive the **plugin root path** as part of your
task input — for example: "Plugin root: /Users/mac/.claude/plugins/cache/android-review-marketplace/android-review/2.0.0".
Use it to locate `rules/`. If absent — abort early with:

```
## Android Review

ERROR: plugin root was not supplied by the caller. Cannot locate rules.
This is a bug in the orchestrator (commands/android-review.md).
```

## Procedure (follow exactly)

### Step 1 — Discover rules

List every `*.md` file under `<PLUGIN_ROOT>/rules/{flow,webview,crypto}/`.
Skip files starting with `_` (those are schema/template).

### Step 2 — Read project context

Read `.claude/CLAUDE.md` from the project root. Parse:

- `## project-type` — `with-attribution` or `no-attribution`.
- `## landing-mechanism` — `webview`, `custom-tabs`, or `none`.
- `## redirect-method` — `7.1` / `7.2` / `7.3` (or empty).
- `## backend-domain` — the URL.
- `## accepted-deviations` — lines of form `<rule-id>: <reason>`
  (lines starting with `#` are comments, ignored).

If `.claude/CLAUDE.md` is missing — proceed with `project-type =
with-attribution` (default), `landing-mechanism = webview`,
`redirect-method = `, `backend-domain = `, `accepted-deviations = ∅`.
Note in the report header.

### Step 3 — Filter rules

For each rule:
- Read frontmatter only.
- If `requires-project-type` is set and doesn't match the project's
  `project-type` → skip; record under "Пропущені перевірки" with
  reason `project-type: <required> required, current: <actual>`.
- If rule's `id` appears in `accepted-deviations`:
  - Read rule's `## Виключення` section.
  - If it says `Жодних` → DO NOT skip. Add a `suspicious` finding
    `[plugin/accepted-deviations-rejected]` noting the user tried to
    silence an unsilenceable rule.
  - Otherwise → skip; record under "Пропущені перевірки" with the
    user's verbatim reason.

### Step 4 — Knowledge-currency check (context7 MCP)

For each surviving rule, before applying, consult context7:
1. Resolve relevant library/topic with
   `mcp__plugin_context7_context7__resolve-library-id`.
2. Query docs with
   `mcp__plugin_context7_context7__query-docs` whether the rule's
   claim is still accurate for the current stable Android ecosystem.
3. If context7 says the issue is no longer applicable — skip the rule;
   record under "Пропущені перевірки" with the context7 quote as
   reason.
4. If context7 is unavailable/inconclusive — proceed with the rule
   (fail-open); tag any emitted finding with `(context7: inconclusive)`.

### Step 5 — Apply each surviving rule

For each rule:
1. Read full body.
2. Follow the `## Як перевірити` recipe — this is **dataflow tracing**,
   not grep. Read entry points (`Application.onCreate`, launcher
   Activity, splash composables), trace startup call chains, verify
   the invariant.
3. For each violation — emit a finding using the `## Як доповідати`
   template literally. Body is **Ukrainian**.
4. For each rule that PASSED (no violations) — note for the
   "Перевірені інваріанти" section.

### Step 6 — Group findings by severity

- `critical` → "Критичні баги функціональної логіки".
- `suspicious` → "Підозрілі патерни".
- `observation` → "Спостереження".

Within each severity, sort by file path (lexicographic) then line
number (ascending). Findings without a parseable `<file>:<line>` go
last.

### Step 7 — Output

Produce a markdown report with this exact structure (do NOT wrap the
entire output in a code fence):

```
## Android Review

(use this exact heading — the orchestrator merges your output into the
final report)

**CLAUDE.md:** found ✓ | missing ⚠️ | partially parseable ⚠️
**project-type:** with-attribution | no-attribution
**landing-mechanism:** webview | custom-tabs | none
**redirect-method:** 7.X | (none)
**backend-domain:** <URL or "(none)">

### Критичні
(finding blocks for critical-severity, or "(відсутні)")

### Підозрілі
(finding blocks for suspicious-severity, or "(відсутні)")

### Спостереження
(finding blocks for observation-severity, or "(відсутні)")

### Перевірені інваріанти
- ✅ <rule-id-1> — <one-line UA description of what it verified>
- ✅ <rule-id-2> — ...
(or "(жодне правило не дійшло до перевірки)" if all were skipped)

### Пропущені перевірки
- <rule-id> — <reason in Ukrainian>
(or "(відсутні)")
```

## Output language constraint (MANDATORY)

ALL human-readable text in your output MUST be in Ukrainian:
- Finding descriptions, "Як виправити:", "Див.:".
- Reasons under "Пропущені перевірки".
- "Перевірені інваріанти" descriptions.

What stays English (machine-readable tokens):
- Rule IDs and severity tags: `[flow/uuid-persistence] CRITICAL`.
- File paths, line numbers, code identifiers in backticks.
- Structural section headers (`## Android Review`, `### Критичні`,
  etc.) — but NOTE the section names themselves are Ukrainian.

If a rule's template contains English text — translate it to Ukrainian
on the way out.

## Hard constraints

- **Read-only**. You have only `Read`, `Glob`, `Grep`, and the
  context7 MCP tools. You **cannot** modify any file.
- **No path pinning**. Do not require specific file paths or class
  names. Verify functional behavior, not structure.
- **No fabrication**. If you cannot confidently verify a rule's
  invariant via dataflow — emit the finding tagged `(context7:
  inconclusive)` or note in the rule's body. Never guess.
- **Stable output**. Sort findings by file then line. Identical
  inputs produce identical reports.
- **Single Task call**. You are dispatched once by the slash command
  and run to completion. Do not attempt to dispatch further sub-agents
  (Task is unavailable inside sub-agents in Claude Code 2.1.x).
````

- [ ] **Step 2: Verify**

```bash
cd /Users/mac/CodeReviewSystem
head -1 agents/functional-validator.md | grep -q "^---$" && \
  grep -q "^name: functional-validator$" agents/functional-validator.md && \
  grep -q "Knowledge-currency check (context7 MCP)" agents/functional-validator.md && \
  grep -q "Output language constraint (MANDATORY)" agents/functional-validator.md && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add agents/functional-validator.md
git commit -m "feat(agent): single functional-validator replaces 3 v1.x sub-agents"
```

---

## Task 12: Rewrite `commands/android-review.md`

**Files:**
- Modify: `commands/android-review.md` (full rewrite)

- [ ] **Step 1: Replace the file content**

Write `/Users/mac/CodeReviewSystem/commands/android-review.md` (overwriting the existing v1.x version):

````markdown
---
description: Run a full Android Review of the current project — functional validation against the team's contract. Saves report to .claude/reports/.
---

# /android-review (v2.0)

Run a complete functional review on the project at the current working
directory.

## What this does

1. Validates that you are at the root of an Android project (looks for
   `app/build.gradle(.kts)`).
2. Auto-detects plugin root (Claude Code 2.1.x doesn't expose
   `${CLAUDE_PLUGIN_ROOT}` to slash commands).
3. Reads `.claude/CLAUDE.md` (5 fields: project-type, landing-mechanism,
   redirect-method, backend-domain, accepted-deviations).
4. Dispatches the `functional-validator` sub-agent. The agent applies
   8 functional rules via dataflow tracing.
5. Saves the report as `.claude/reports/<project-id>-android-review.md`,
   archiving the previous one to `archive/<project-id>-<timestamp>.md`.
6. Prints a compact summary in the terminal.

## Usage

```
cd <android-project-root>
claude
/android-review
```

---

## Step 1 — Validate Android project root

Use `Glob` (not Bash) to check for `app/build.gradle.kts` or
`app/build.gradle` in cwd.

If neither exists, your ENTIRE response must be exactly the two lines
below — verbatim, in English, no preamble, no postamble, no
translation, no follow-up:

```
This is not an Android project root. Expected app/build.gradle(.kts) — not found.
Did you cd to the project root before launching claude?
```

After printing, STOP. Do NOT call any further tools. Do NOT translate.
Do NOT scan filesystem for nearby Android projects.

## Step 2 — Locate plugin root (runtime auto-detection)

Use Bash:

```
ls -td "$HOME/.claude/plugins/cache/android-review-marketplace/android-review/"*/ 2>/dev/null | head -1
```

Take the first line of stdout (the most recently-installed version's
directory). Strip trailing slash. Bind as `PLUGIN_ROOT`.

If output is empty, abort with:

```
Cannot locate the android-review plugin's installation under $HOME/.claude/plugins/cache/android-review-marketplace/. Reinstall via /plugins → Marketplaces → Update marketplace.
```

## Step 3 — Determine project-id

- If `.claude/CLAUDE.md` exists and `## project-id` parses to a
  non-empty token, use that value.
- Otherwise, fall back to `pwd | xargs basename`, lowercase,
  whitespace/underscores → `-`, collapse multiple `-`. (`xargs` may
  trigger one-time permission prompt — acceptable.)

## Step 4 — Dispatch the functional-validator

Use the `Task` tool with `subagent_type: functional-validator` and this
prompt body. Substitute the discovered `PLUGIN_ROOT`:

```
Plugin root: <PLUGIN_ROOT>

Run a full functional Android review on the project at the current working directory. Follow your system prompt's procedure exactly. Return the markdown report only.
```

Wait for the agent's return. The agent returns a markdown report whose
top-level heading is `## Android Review`.

## Step 5 — Read project metadata for the report header

Use `Read` on `<PLUGIN_ROOT>/.claude-plugin/plugin.json` and parse
`version` field.

Use Bash `date "+%Y-%m-%d %H:%M"` for the report date (capture as
`REPORT_DATE`, use once).

## Step 6 — Compose the final report (Ukrainian)

Take the agent's output and wrap it in the report skeleton:

```
# Android Review — <project-id>

**Дата:** <REPORT_DATE>  •  **Версія плагіна:** <plugin-version>
**Тип проєкту:** <project-type>  •  **Лендинг:** <landing-mechanism>  •  **Метод редіректу:** <redirect-method or "n/a">

## Вердикт: <verdict>

---

<entire agent output, with "## Android Review" stripped — only its subsections>

---
```

Verdict computation:
- 0 critical AND 0 suspicious → `✅ ГОТОВО`.
- 0 critical AND ≥1 suspicious → `⚠️ З ЗАСТЕРЕЖЕННЯМИ`.
- ≥1 critical → `🔴 НЕ ГОТОВО`.

## Step 7 — Save report (with N3 archive)

Compute archive timestamp ONCE: `date "+%Y-%m-%d-%H%M"` → `TS`.

Sequence (Bash):

```
mkdir -p .claude/reports/archive
[ -f ".claude/reports/<project-id>-android-review.md" ] && \
  mv ".claude/reports/<project-id>-android-review.md" \
     ".claude/reports/archive/<project-id>-<TS>.md"
```

Use `Write` to create `.claude/reports/<project-id>-android-review.md`
with the full report from Step 6.

## Step 8 — Terminal summary (NOT the full report)

Print ONLY this compact summary as your final assistant message:

```
# Android Review — <project-id>

**Дата:** <REPORT_DATE>  •  **Плагін:** <plugin-version>
**Тип:** <project-type>  •  **Лендинг:** <landing-mechanism>  •  **Редірект:** <redirect-method or "n/a">

**Вердикт:** <verdict>

**Критичні:** <count>
**Підозрілі:** <count>
**Спостереження:** <count>
**Пропущено правил:** <count>

**Збережено:** `.claude/reports/<project-id>-android-review.md`
```

If the save step fails, replace the `**Збережено:**` line with:
`**Збережено:** ПОМИЛКА — <reason>`. Never retry. Never print the
full report as a fallback.

## Mandatory dispatch discipline

Do NOT do any of the following:
- Skip steps because "this doesn't look like an Android project" — Step 1
  handles that case.
- Translate the abort message in Step 1 (verbatim English).
- Decide on your own to scan `~/StudioProjects/` or any other directory.
- Ask the user "which project to check?".
- Reply with anything before dispatching the agent (Step 4).
````

- [ ] **Step 2: Verify**

```bash
cd /Users/mac/CodeReviewSystem
head -3 commands/android-review.md | grep -q "v2.0" && \
  grep -q "subagent_type: functional-validator" commands/android-review.md && \
  grep -q "## Step 4 — Dispatch" commands/android-review.md && \
  grep -q "## Вердикт:" commands/android-review.md && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add commands/android-review.md
git commit -m "feat(commands): rewrite /android-review for v2.0 single-agent dispatch + new report shape"
```

---

## Task 13: Rewrite `commands/android-review-init.md`

**Files:**
- Modify: `commands/android-review-init.md` (full rewrite)

- [ ] **Step 1: Replace file content**

Write `/Users/mac/CodeReviewSystem/commands/android-review-init.md`:

````markdown
---
description: Initialize .claude/CLAUDE.md scaffold (5 fields, 3 auto-detected) for the current Android project. Run once before /android-review.
---

# /android-review-init (v2.0)

Create a `.claude/CLAUDE.md` scaffold for the current Android project,
auto-filling `project-type`, `landing-mechanism`, and `backend-domain`
from the project's source. Leaves `redirect-method` and
`accepted-deviations` as TODO for the human.

Also appends `.claude/reports/` to the project's `.gitignore`.

## When to use

Run this ONCE per Android project, before the first `/android-review`.
After it creates the file, edit the `redirect-method` TODO and run the
full review.

## Usage

```
cd <android-project-root>
claude
/android-review-init
```

---

## Step 1 — Validate Android project root

Same hard-abort as `/android-review`. If neither
`app/build.gradle.kts` nor `app/build.gradle` exists, print exactly:

```
This is not an Android project root. Expected app/build.gradle(.kts) — not found.
Did you cd to the project root before launching claude?
```

Then STOP.

## Step 2 — Refuse to overwrite existing CLAUDE.md

Use `Read` on `.claude/CLAUDE.md`. If the file exists, print exactly:

```
.claude/CLAUDE.md already exists — nothing to do.

If you want to regenerate it from scratch, delete the file first:
  rm .claude/CLAUDE.md
Then run `/android-review-init` again.
```

Then STOP.

If the read fails with file-not-found, proceed.

## Step 3 — Auto-detect project-type

Use `Read` on `gradle/libs.versions.toml` (preferred) or
`app/build.gradle.kts`. Look for any of:
- `OneSignal` (case-insensitive substring)
- `installreferrer`
- `play-services-ads-identifier`

If at least one is present → `project-type = with-attribution`.
Otherwise → `project-type = no-attribution`.

## Step 4 — Auto-detect landing-mechanism

Use `Glob` and `Grep` on `app/src/main/java/**/*.kt`:
- Search for `WebView(` or `findViewById<WebView>` or
  `AndroidView { factory = { WebView`.
- Search for `CustomTabsIntent`.

Decision:
- Only WebView → `landing-mechanism = webview`.
- Only CustomTabs → `landing-mechanism = custom-tabs`.
- Both → leave as TODO with note `# TODO: choose webview or custom-tabs`.
- Neither → `landing-mechanism = none`.

## Step 5 — Auto-detect backend-domain

Use `Grep` on `app/src/main/java/**/*.kt` (and `**/*.java`) for HTTPS
URL literals matching common production-domain TLDs:
`https://[a-z0-9.-]+\.(store|app|io|dev|com)`.

Filter out:
- `localhost`, `127.0.0.1`, `10.0.2.2`.
- Common library domains: `firebase.com`, `googleapis.com`,
  `firebaseapp.com`, `crashlytics.com`, `google.com`, `android.com`,
  `developer.android.com`.

If exactly one unique domain remains → auto-fill. Else → TODO.

## Step 6 — Compute project-id

Bash: `pwd | xargs basename`, lowercase, whitespace/underscores → `-`.

## Step 7 — Create .claude/ and write CLAUDE.md

Bash: `mkdir -p .claude`.

Use `Write` to create `.claude/CLAUDE.md` with this content (substitute
detected values):

```markdown
# Project context for Claude Code

(Free-form short description, optional.)

---

# Android Review configuration

## project-id

<COMPUTED_PROJECT_ID>

## project-type

<DETECTED_PROJECT_TYPE>

## landing-mechanism

<DETECTED_LANDING_MECHANISM>

## redirect-method

# TODO: Choose one of the supported methods used in this project's
# Privacy Policy → game flow:
#   - 7.1 webMessageListener
#   - 7.2 consoleLog
#   - 7.3 shouldOverrideUrlLoading
# Plugin verifies ONLY this method's correctness.
# Leave empty if landing-mechanism = none or custom-tabs.

## backend-domain

<DETECTED_BACKEND_DOMAIN_OR_TODO>

## accepted-deviations

# Lines starting with `#` are comments and are IGNORED.
# To silence a specific functional check, write a non-commented line:
#   <rule-id>: <reason why this deviation is accepted>
```

## Step 8 — Append `.claude/reports/` to project's .gitignore

```
grep -qxF '.claude/reports/' .gitignore 2>/dev/null || printf '\n# Claude Code Android Review reports\n.claude/reports/\n' >> .gitignore
```

## Step 9 — Print onboarding message

Print exactly (substitute values):

```
✅ Created .claude/CLAUDE.md for project: <project-id>

Auto-filled:
  • project-type: <project-type>
  • landing-mechanism: <landing-mechanism>
  • backend-domain: <backend-domain or "TODO">

TODO before running the full review:
  • Open .claude/CLAUDE.md and set `redirect-method` (one of 7.1 / 7.2 / 7.3).
  • If backend-domain is TODO, set it to the actual production URL.

Also done:
  • .claude/reports/ added to project's .gitignore.

Next step:
  /android-review
```

Then STOP. Do NOT run the full review automatically.

## Hard constraints

- Do NOT overwrite an existing `.claude/CLAUDE.md` (Step 2).
- Do NOT modify any project source files.
- Do NOT fabricate detected values. If detection failed, leave TODO.
````

- [ ] **Step 2: Verify**

```bash
cd /Users/mac/CodeReviewSystem
grep -q "v2.0" commands/android-review-init.md && \
  grep -q "DETECTED_PROJECT_TYPE" commands/android-review-init.md && \
  grep -q "DETECTED_LANDING_MECHANISM" commands/android-review-init.md && \
  grep -q "DETECTED_BACKEND_DOMAIN_OR_TODO" commands/android-review-init.md && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add commands/android-review-init.md
git commit -m "feat(commands): rewrite /android-review-init for v2.0 5-field scaffold + auto-detection"
```

---

## Task 14: Rewrite `examples/good-claude-md-for-project.md`

**Files:**
- Modify: `examples/good-claude-md-for-project.md` (full rewrite)

- [ ] **Step 1: Write the file**

Write `/Users/mac/CodeReviewSystem/examples/good-claude-md-for-project.md`:

```markdown
# Project context for Claude Code

Sample Android casual game with attribution flow. Splash queries the
backend for routing, then either gameplay (organic users still go
through landing) or WebView landing (always opened, regardless of
organic/non-organic). OneSignal + Install Referrer + AdsId integrations.

---

# Android Review configuration

## project-id

example-juicer

## project-type

with-attribution

## landing-mechanism

webview

## redirect-method

7.1 webMessageListener

## backend-domain

https://example.store

## accepted-deviations

# Lines starting with `#` are comments and are IGNORED.
# To silence a specific functional check, write a non-commented line:
#   <rule-id>: <reason>
# Example (only fires if a real deviation exists):
# webview/config-completeness: project intentionally uses minimal WebView for read-only landing page
```

- [ ] **Step 2: Verify**

```bash
cd /Users/mac/CodeReviewSystem
grep -q "## project-type" examples/good-claude-md-for-project.md && \
  grep -q "## landing-mechanism" examples/good-claude-md-for-project.md && \
  grep -q "## redirect-method" examples/good-claude-md-for-project.md && \
  grep -q "## backend-domain" examples/good-claude-md-for-project.md && \
  grep -q "## accepted-deviations" examples/good-claude-md-for-project.md && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add examples/good-claude-md-for-project.md
git commit -m "docs(examples): update good-claude-md-for-project to v2.0 5-field shape"
```

---

## Task 15: Update `docs/project-claude-md-template.md` and `docs/how-to-add-a-rule.md` and `docs/smoke-test.md`

**Files:**
- Modify: `docs/project-claude-md-template.md` (full rewrite)
- Modify: `docs/how-to-add-a-rule.md` (full rewrite)
- Modify: `docs/smoke-test.md` (full rewrite)

- [ ] **Step 1: Rewrite `docs/project-claude-md-template.md`**

Write `/Users/mac/CodeReviewSystem/docs/project-claude-md-template.md`:

```markdown
# Project `.claude/CLAUDE.md` template (v2.0)

Place this file at the root of an Android project that will be reviewed
with `/android-review`. It serves two purposes:
1. Project context auto-loaded by Claude Code.
2. Machine-readable declarations parsed by the `functional-validator`
   agent.

## Template

```markdown
# Project context for Claude Code

(Free-form short description, optional.)

---

# Android Review configuration

## project-id

<short-kebab-case-id>

## project-type

with-attribution    # or: no-attribution

## landing-mechanism

webview             # or: custom-tabs | none

## redirect-method

7.1 webMessageListener    # or: 7.2 consoleLog | 7.3 shouldOverrideUrlLoading

## backend-domain

https://example.store

## accepted-deviations

# rule-id: justification
```

## Section reference

| Section               | Purpose                                                                                           | Required?    |
|-----------------------|---------------------------------------------------------------------------------------------------|--------------|
| `project-id`          | Human-readable id used in report titles and filenames.                                            | Yes          |
| `project-type`        | `with-attribution` or `no-attribution` — controls whether attribution-flow rules apply.           | Yes          |
| `landing-mechanism`   | `webview`, `custom-tabs`, or `none` — controls which WebView/CustomTabs rules apply.              | Yes          |
| `redirect-method`     | `7.1` / `7.2` / `7.3` — which Privacy Policy → game redirect to verify. Leave empty if landing = none/custom-tabs. | Yes (if landing = webview) |
| `backend-domain`      | Production backend URL for attribution POST and WebView load.                                     | Yes (if project-type = with-attribution) |
| `accepted-deviations` | `<rule-id>: <reason>` — silences a specific functional check with written justification.          | Optional     |

## Auto-detection

`/android-review-init` auto-fills `project-type`, `landing-mechanism`,
and `backend-domain` from the project's gradle and source. The other
two fields (`redirect-method`, `accepted-deviations`) are TODO for the
human because they cannot be reliably guessed.

## What happens if `.claude/CLAUDE.md` is missing

The plugin does NOT fail. The `functional-validator` agent uses
defaults: `project-type = with-attribution`,
`landing-mechanism = webview`, empty `redirect-method`, empty
`backend-domain`, empty `accepted-deviations`. Report header notes the
missing file. Findings may be noisier without project context — run
`/android-review-init` to fix.

## What to gitignore

Reports go to `.claude/reports/`. Add this to your project's
`.gitignore`:

```
.claude/reports/
```

`.claude/CLAUDE.md` itself is NOT gitignored — it is configuration,
PR-reviewed by the team.
```

- [ ] **Step 2: Rewrite `docs/how-to-add-a-rule.md`**

Write `/Users/mac/CodeReviewSystem/docs/how-to-add-a-rule.md`:

```markdown
# How to add a rule (v2.0)

## TL;DR

1. `cp rules/_template.md rules/<category>/<your-slug>.md`
   where `<category>` is `flow`, `webview`, or `crypto`.
2. Fill the 5 mandatory frontmatter fields (+ `requires-project-type`
   if applicable).
3. Fill the 6 body sections (Інваріант / Як перевірити / Як виглядає
   поломка / Як виглядає правильно / Як доповідати / Виключення).
4. Bump plugin minor version in `.claude-plugin/plugin.json` and
   `marketplace.json`. Add a CHANGELOG line.
5. PR. Smoke-test against a real team project per `docs/smoke-test.md`
   before merge.

## Choosing the right severity

- **`critical`** — broken invariant causes runtime issue or violates
  the user-defined contract. Verdict becomes `🔴 НЕ ГОТОВО`. Reserve
  for hard contracts (e.g., `flow/organic-routing-critical`).
- **`suspicious`** — non-blocking heuristic, worth a glance. Default
  for most rules.
- **`observation`** — informational, never blocks.

## Choosing the right category

- **`flow/`** — runtime behavior on app startup or attribution
  (UUID, push init, attribution, routing, redirect method).
- **`webview/`** — WebView/CustomTabs configuration and host Activity.
- **`crypto/`** — POST-data encoding pattern (no path pinning).

If a rule doesn't fit these — reconsider whether it should be a static
rule at all. v2.0's philosophy is functional invariants, not generic
best practices.

## `requires-project-type`

Set to `with-attribution` for rules that only apply when attribution is
present (most `flow/` rules). Set to `no-attribution` for rules that
only apply for game-only builds (rare). Leave unset if the rule is
universal (most `webview/` and `crypto/` rules).

## When to use `Жодних` in `## Виключення`

Reserve `Жодних` for hard contracts that the team has decided cannot
be silenced via `accepted-deviations`. Currently this applies only to
`flow/organic-routing-critical` and `flow/uuid-persistence`.

For all other rules, document a narrow exception path with required
justification format.

## Anti-patterns when writing rules

- Don't pin to file paths or class names. The team's apps vary widely
  on structure.
- Don't pin to library versions or specific SDKs. Multiple SDKs may
  achieve the same functional outcome.
- Don't write `## Як перевірити` as a grep recipe. Write it as a
  reasoning recipe — what dataflow chains the agent should trace.
- Don't add rules that require dynamic analysis (HTTP traffic,
  installed APK behavior) — v2.0 is static-only.
- Don't restate generic Android best practices that R8/AGP already
  enforce.
```

- [ ] **Step 3: Rewrite `docs/smoke-test.md`**

Write `/Users/mac/CodeReviewSystem/docs/smoke-test.md`:

```markdown
# Manual smoke-test plan (v2.0)

Run before every release of the plugin (any non-patch bump).
Total time: ~10 minutes.

## Prerequisites

- Plugin installed locally (`/plugin marketplace add Ka7amaran/CodeReviewSystem`
  + `/plugin install`).
- At least one real team Android project at `~/StudioProjects/<project>/`.

## Scenario S1 — Init on a fresh project

Pick any project that doesn't yet have `.claude/CLAUDE.md`:

```
cd ~/StudioProjects/<some-project>
claude
/android-review-init
```

Expected:
- `.claude/CLAUDE.md` created with 5 sections.
- `project-type`, `landing-mechanism`, `backend-domain` auto-filled
  (the latter when uniquely detectable).
- `redirect-method` and `accepted-deviations` are TODO.
- `.claude/reports/` appended to project's `.gitignore`.
- Onboarding message printed with next-step hint.

## Scenario S2 — Refusal on existing CLAUDE.md

Re-run `/android-review-init` in the same project:

Expected:
- Print `.claude/CLAUDE.md already exists — nothing to do.`
- No file modifications.

## Scenario S3 — Full review on with-attribution project

Edit `.claude/CLAUDE.md` from S1 to set `redirect-method: 7.1`. Then:

```
/android-review
```

Expected:
- 3 sub-agent calls visible (no — single dispatch, just one
  `functional-validator` call).
- Compact summary in terminal:
  - Header with project-type/landing-mechanism/redirect-method.
  - Verdict (`✅ ГОТОВО` / `⚠️ З ЗАСТЕРЕЖЕННЯМИ` / `🔴 НЕ ГОТОВО`).
  - Counts per severity.
  - Saved-path.
- Saved file `.claude/reports/<project-id>-android-review.md` exists,
  has the full report with all sections including "Перевірені
  інваріанти" pass list.

## Scenario S4 — Hard-abort on non-Android directory

```
cd /tmp
claude
/android-review
```

Expected: exact two-line English abort message, no further tool calls.

## Scenario S5 — No-attribution project

Edit `.claude/CLAUDE.md` to set `project-type: no-attribution`. Run
`/android-review`. Expected: all `flow/*` rules in "Пропущені
перевірки" with reason
`project-type: with-attribution required, current: no-attribution`.

## Recording results

After release, append to `CHANGELOG.md` under the release entry:
"Smoke-test passed: S1 ✓ S2 ✓ S3 ✓ S4 ✓ S5 ✓".

If any scenario fails, fix BEFORE tagging. Do not mark "known issue".
```

- [ ] **Step 4: Verify**

```bash
cd /Users/mac/CodeReviewSystem
grep -q "v2.0" docs/project-claude-md-template.md && \
  grep -q "v2.0" docs/how-to-add-a-rule.md && \
  grep -q "v2.0" docs/smoke-test.md && \
  grep -q "## project-type" docs/project-claude-md-template.md && \
  grep -q "Інваріант / Як перевірити" docs/how-to-add-a-rule.md && \
  grep -q "Scenario S5 — No-attribution" docs/smoke-test.md && echo OK
```

Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add docs/project-claude-md-template.md docs/how-to-add-a-rule.md docs/smoke-test.md
git commit -m "docs: rewrite project-claude-md-template, how-to-add-a-rule, smoke-test for v2.0"
```

---

## Task 16: Bump version + CHANGELOG

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Bump plugin.json**

```bash
cd /Users/mac/CodeReviewSystem
```

Edit `/Users/mac/CodeReviewSystem/.claude-plugin/plugin.json`. Change
the `"version"` line from `"1.5.0"` to `"2.0.0"`.

Also update `description` field to:
```
"Functional validator for Android (Kotlin/Compose/Hilt) projects. Verifies attribution flow, WebView setup, and POST-encoding pattern via dataflow tracing — not structural grep."
```

- [ ] **Step 2: Bump marketplace.json**

Edit `/Users/mac/CodeReviewSystem/.claude-plugin/marketplace.json`.
Change the `"version"` line in the plugin entry from `"1.5.0"` to
`"2.0.0"`. Also update the `description` field to the same string as
in plugin.json.

- [ ] **Step 3: Add CHANGELOG entry**

Edit `/Users/mac/CodeReviewSystem/CHANGELOG.md`. Insert this entry
ABOVE the existing `## [1.5.0]` entry (right under the file header):

```markdown
## [2.0.0] — 2026-05-05

### BREAKING — full philosophy rewrite

v2.0 is a ground-up rewrite around a **functional contract** instead
of structural matching. v1.x rules (style/security/obfuscation) are
deleted in full. Reports become 3-severity (Критичні / Підозрілі /
Спостереження) with a "Перевірені інваріанти" pass list, not the v1.x
4-section by-category split.

### Architecture changes

- Single sub-agent `functional-validator` replaces 3 v1.x sub-agents
  (style/security/obfuscation auditors).
- 2 slash commands (`/android-review`, `/android-review-init`)
  replace the 5 v1.x commands. Specialized `-style`/`-security`/
  `-obfuscation` commands removed.
- 8 functional rules across 3 new categories (`flow/`, `webview/`,
  `crypto/`) replace 21 v1.x structural rules.
- Output: only `.md` (the `.gdoc.txt` second format is removed; paste
  `.md` directly into Google Docs if needed).

### Removed (entire v1.x rule set)

- All 8 `style/*` rules.
- All 7 `security/*` rules.
- All 6 `obfuscation/*` rules.
- `cross/exported-component-not-keep` (cross-cutting check obsolete in
  functional model).

### Added (v2.0 rule catalog)

- `flow/initial-startup-checklist` — all 6 startup actions present.
- `flow/uuid-persistence` — UUID survives between sessions.
- `flow/organic-routing-critical` — organic users still open WebView
  (THE most important v2.0 invariant).
- `flow/non-organic-post-required` — non-organic users POST to backend.
- `flow/redirect-method-correctness` — only the declared method is
  verified (one of 7.1 / 7.2 / 7.3).
- `webview/config-completeness` — canonical preset of WebView settings.
- `webview/activity-fullscreen-orientation` — Activity orientation,
  fullscreen, top-bar visibility.
- `crypto/post-data-encoding-pattern` — POST data goes through a
  consistent encoding (no path pinning).

### CLAUDE.md scaffold

- 5 fields (`project-type`, `landing-mechanism`, `redirect-method`,
  `backend-domain`, `accepted-deviations`) replace the 6 v1.x fields.
- 3 of 5 are auto-detected by `/android-review-init`.
- `accepted-risks` renamed to `accepted-deviations` (functional vs
  risk-based framing).

### Migration

v1.x stays accessible via `git checkout v1.5.0` — no automatic
migration path. v2.0 is a clean cutover.
```

- [ ] **Step 4: Verify**

```bash
cd /Users/mac/CodeReviewSystem
grep -q '"version": "2.0.0"' .claude-plugin/plugin.json && \
  grep -q '"version": "2.0.0"' .claude-plugin/marketplace.json && \
  grep -q "## \[2.0.0\] — 2026-05-05" CHANGELOG.md && echo OK
```

Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
cd /Users/mac/CodeReviewSystem
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md
git commit -m "release: v2.0.0 — functional-validator (full rewrite)"
```

---

## Task 17: End-to-end smoke-test on a real project

This task is a **manual run** of all 5 scenarios from
`docs/smoke-test.md` against a live Android project. No new files
created; outputs are observed and compared.

- [ ] **Step 1: Install the plugin from the local repo**

In a fresh Claude Code session (not the one writing this plan):

```
/plugin marketplace remove android-review-marketplace
/plugin marketplace add /Users/mac/CodeReviewSystem
/plugin install android-review@android-review-marketplace
```

Choose user-scope. Verify installed version is `2.0.0` in `/plugins`
→ `Installed`.

- [ ] **Step 2: Run S1 (init on fresh project)**

Pick a project without `.claude/CLAUDE.md` — e.g., temporarily move
existing one aside:

```
cd ~/StudioProjects/Juice-Master-Factory
mv .claude/CLAUDE.md /tmp/CLAUDE.md.bak 2>/dev/null
```

In Claude Code session:
```
/android-review-init
```

Verify: file created with 5 sections, auto-detected values present,
onboarding message printed.

- [ ] **Step 3: Run S2 (refusal on existing CLAUDE.md)**

In the same project, immediately re-run:
```
/android-review-init
```

Verify: refusal message, no file modification.

- [ ] **Step 4: Run S3 (full review on with-attribution project)**

Edit `.claude/CLAUDE.md` to set `redirect-method: 7.1`. Then:
```
/android-review
```

Verify: terminal shows compact summary; `.claude/reports/<project-id>-android-review.md`
created; report has all sections per spec §5.

- [ ] **Step 5: Run S4 (hard-abort on non-Android dir)**

```
cd /tmp
claude
/android-review
```

Verify: exact two-line English abort, no further tool calls.

- [ ] **Step 6: Run S5 (no-attribution project)**

Restore CLAUDE.md and edit `project-type: no-attribution`. Run
`/android-review`. Verify all `flow/*` rules in "Пропущені перевірки"
with reason "project-type: with-attribution required, current:
no-attribution".

- [ ] **Step 7: Restore baseline state**

```
mv /tmp/CLAUDE.md.bak ~/StudioProjects/Juice-Master-Factory/.claude/CLAUDE.md 2>/dev/null
```

(Or update the test project's CLAUDE.md to the v2.0 5-field shape if
keeping it.)

- [ ] **Step 8: Append smoke-test result to CHANGELOG**

Edit `/Users/mac/CodeReviewSystem/CHANGELOG.md`. Inside the
`## [2.0.0] — 2026-05-05` entry, append at the bottom:

```
### Smoke-test

Smoke-test passed on <YYYY-MM-DD> against `<project-name>`:
S1 ✓ S2 ✓ S3 ✓ S4 ✓ S5 ✓.
```

Replace `<YYYY-MM-DD>` with today's date and `<project-name>` with the
project actually tested.

```bash
cd /Users/mac/CodeReviewSystem
git add CHANGELOG.md
git commit -m "chore: record v2.0 smoke-test pass"
```

---

## Task 18: Tag v2.0.0 and push

**Files:** none (git operations only).

- [ ] **Step 1: Confirm clean working tree and full commit history**

```bash
cd /Users/mac/CodeReviewSystem
git status
git log --oneline | head -25
```

Expected: clean tree; commit history shows the v2.0 commits from
Tasks 1-17.

- [ ] **Step 2: Create the annotated tag**

```bash
cd /Users/mac/CodeReviewSystem
git tag -a v2.0.0 -m "v2.0.0 — functional validator: full rewrite from v1.x structural model

Single agent, 8 functional rules, 5-field CLAUDE.md scaffold, 3-severity
report with 'Перевірені інваріанти' pass list. Driven by
docs/specs/2026-05-05-v2-functional-validator-design.md."
```

- [ ] **Step 3: Push main + tags**

```bash
cd /Users/mac/CodeReviewSystem
git push origin main
git push origin v2.0.0
```

- [ ] **Step 4: Verify on GitHub**

Open `https://github.com/Ka7amaran/CodeReviewSystem/releases` in
browser. Verify `v2.0.0` tag is present. Optionally create a Release
from the tag with the `## [2.0.0]` CHANGELOG entry pasted as release
notes.

---

## Self-Review (executed during plan authoring)

**1. Spec coverage check:**

- §1 Context — addressed by the entire plan, no specific task needed.
- §2 Philosophy — embedded in Task 11 (agent prompt) and Tasks 3-10
  (rule bodies' `## Як перевірити` framing).
- §3 Functional contract — Tasks 3-10 each implement one
  numbered subsection (3.1 → Task 3, 3.2 → Task 4, 3.6 → Task 5,
  3.6/3.5 → Task 6, 3.7 → Task 7, 3.9 → Task 8, 3.8 → Task 9, 3.10 →
  Task 10).
- §4 CLAUDE.md scaffold — Tasks 13 (init command) + 14 (example) +
  15 (template doc).
- §5 Report format — Task 12 (command body Step 6 + Step 8).
- §6 Files — Task 12 (command Step 7).
- §7 Slash commands — Task 1 (cleanup) + Task 12-13 (rewrites).
- §8 Internal architecture — Task 11 (single agent) + Task 12
  (orchestration in command body).
- §9 Rules catalog — Tasks 3-10.
- §10 Out-of-scope rules — Task 1 (deletion).
- §11 Migration — Tasks 1, 14, 15, 16.
- §12 Verification — Task 17 + 18.
- §13 Decisions log — informational, no task.

No spec gaps.

**2. Placeholder scan:** searched for "TBD", "TODO", "implement
later", "fill in details", "Add appropriate error handling",
"Similar to Task N", "Write tests for the above". The TODO markers
that DO appear are inside literal CLAUDE.md template text (intentional
guidance for the human user, written verbatim). Code/command steps all
contain complete content. Pass.

**3. Type consistency:** `functional-validator` agent name appears in
Task 11 (creation), Task 12 (`subagent_type: functional-validator`),
and the agent's frontmatter — matches. Section names "Критичні",
"Підозрілі", "Спостереження", "Перевірені інваріанти", "Пропущені
перевірки" appear identically in agent prompt (Task 11), command body
(Task 12), and design spec (already committed). Verdict tokens
"✅ ГОТОВО / ⚠️ З ЗАСТЕРЕЖЕННЯМИ / 🔴 НЕ ГОТОВО" match between agent,
command, and spec. Rule IDs in CHANGELOG match the rule files'
frontmatter ids. Pass.

---

## Execution handoff

Plan complete and saved to `docs/plans/2026-05-05-v2-functional-validator-implementation.md`.

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per
task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using
`superpowers:executing-plans`, batch execution with checkpoints.

Which approach?
