# Android Review v2.0 — Functional Validator Design

- **Date:** 2026-05-05
- **Status:** Draft, awaiting user review
- **Author:** Roman (with Claude Opus 4.7)
- **Supersedes:** `2026-04-29-android-review-system-design.md` (v1.x)
- **Source of truth for functional contract:** `/Users/mac/Downloads/android_app_analysis_prompt.md`
  (the user-provided checklist that drove this redesign)

---

## 1. Context

The plugin shipped through v1.5.0 with 21 rules across 3 categories
(style/security/obfuscation), built bottom-up from generic Android
best-practices. After running it on multiple real team apps, the user
concluded the reports are not useful: findings are noisy or
irrelevant for the team's specific architecture (game + WebView/
CustomTabs landing flow + attribution), some real issues are missed
because the generic rules don't recognize team-specific patterns,
and the 3-category split doesn't match how the team actually triages.

Root cause: v1.x is a **structure validator** — it checks "is the
file/class/setting present in the expected shape", attaching to file
paths, package names, library versions, AGP-specific defaults. The
team's apps vary widely on those structural axes (different DI/UI/
networking libraries, different package layouts, different obfuscation
configs) but converge on a small set of **functional behaviors** at
runtime (UUID handling, attribution flow, organic-vs-non-organic
routing, WebView config completeness).

v2.0 is a ground-up rewrite around the functional contract. Rules
become **dataflow checks**, not grep-patterns. Reports surface
"which functional invariant is broken and where", not "which file
is missing keyword X".

## 2. Philosophy

- **Functional validator, not structure validator.** Verify the
  fact of behavior, not the location/shape of the code that produces
  it.
- **Don't pin to file paths, class names, library versions, SDKs.**
  The same outcome may be achieved many ways across the team's apps;
  none of those variations is a defect.
- **Catch broken behavior, not stylistic deviation.** The bar is
  "does the app do what it should at runtime", not "does the source
  match an example template".
- **Each rule = a dataflow trace** ("X is generated → stored → read
  later"), not a grep over file contents.

## 3. Functional contract (from `android_app_analysis_prompt.md`)

The team's apps are hybrid: game core + landing/policy WebView (or
CustomTabs). The plugin's job is to verify the runtime behavior
matches the contract below. The contract is the source of truth for
every rule v2.0 ships.

### 3.1. Initial startup checklist (for `with-attribution` projects)

The following actions must occur in any order, anywhere in the code
(not necessarily on a "splash" screen):

1. UUID retrieved or generated.
2. Push service initialized (OneSignal or equivalent) with login(uuid).
3. Install Referrer fetched.
4. AdId fetched.
5. Backend domain request issued.
6. Routing decision made (WebView/CustomTabs vs game).

### 3.2. UUID lifecycle

- If a stored UUID exists → reuse it.
- If not → generate a new one and store it.
- Storage mechanism unrestricted: SharedPreferences,
  EncryptedSharedPreferences, Room, DataStore, Firebase, anything.
- Plugin only verifies persistence between sessions and reuse
  downstream.

### 3.3. Push service initialization

- Equivalent of `OneSignal.initWithContext(context, appId)` +
  `OneSignal.login(uuid)`.
- Location of init is irrelevant — not necessarily SplashActivity.

### 3.4. Install Referrer

- Standard `InstallReferrerClient` OR third-party SDK (AppsFlyer,
  Tenjin, Adjust, others).
- Plugin only verifies the fact of fetch.

### 3.5. AdId

- `AdvertisingIdClient` from `play-services-ads-identifier` OR
  alternative SDK/wrapper.
- Plugin only verifies the fact of fetch.

### 3.6. Routing logic by referrer (CRITICAL)

For all users, organic AND non-organic:
- Domain request: yes for both.
- UUID transmission: yes for both.
- WebView/CustomTabs launch: **yes for both**.

For non-organic only:
- POST request to backend with `{uuid, ref, adId}`.

If an organic user goes directly to the game, bypassing the domain
request and WebView — this is a **critical bug** the plugin must
flag. This is the single most important invariant.

Organic determined by referrer containing
`utm_source=google-play&utm_medium=organic`.

### 3.7. Privacy Policy → game redirect methods (only 7.1, 7.2, 7.3)

Each of 7.1 and 7.2 has two trigger variants:
- **on-button-click** — web page button calls a JS function the
  Android side intercepts.
- **on-page-load-finish** — Android observes page-load completion
  and gets the signal automatically.

**7.1 webMessageListener** — web sends via
`appBridge.postMessage(...)`; Android listens via
`WebViewCompat.addWebMessageListener` with origin restriction.

**7.2 consoleLog** — web emits `console.log("APP_ACTION: GO_GAME")`;
Android intercepts in `WebChromeClient.onConsoleMessage()`.

**7.3 shouldOverrideUrlLoading** — Privacy Policy presence is
inferred when `shouldOverrideUrlLoading` is NOT called before
`onPageStarted`; that signal triggers navigation to a stub.

**7.4 onPageFinished+title** — currently unused, but the plugin
should be aware (no rule fires, but no warning either if a project
adopts it).

**Deep link `app://accept`** — only used with Custom Tabs, never
with WebView.

The plugin verifies correctness of ONLY the redirect method
declared in `redirect-method` of CLAUDE.md (it doesn't search for
all methods).

### 3.8. WebView/CustomTabs Activity requirements

- Free orientation (no portrait/landscape lock).
- Fullscreen mode without exceptions.
- Top status bar always visible (battery/network indicators).
- System navigation buttons either static-and-visible or
  dynamic-via-swipe.

### 3.9. WebView config (canonical preset)

The team's standard WebView setup includes (and the plugin verifies
presence of):

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
- `importantForAutofill = IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS`
  (API 26+)
- `CookieManager.setAcceptCookie(true)` +
  `setAcceptThirdPartyCookies(webView, true)`
- `webViewClient` and `webChromeClient` set

Optional (not flagged as missing if absent, but verified as
non-broken if present):
- Google Sign-In support inside WebView.
- External link handling (Telegram, Instagram, TikTok, other
  app deep-link schemes).

### 3.10. Crypto layer

- File paths and class names are NOT pinned.
- Files may live anywhere; names may be anything (especially after
  obfuscation).
- The single invariant: a consistent encoding pattern for the data
  sent in the POST request to the backend domain. Plugin verifies
  the pattern, not the file location.

### 3.11. Out of scope (explicitly NOT flagged)

- Empty `proguard-rules.pro` even with `isMinifyEnabled = true`
  (Hilt + kotlinx.serialization + Compose ship consumer-rules).
- MainActivity without `-keep` (verified to work).
- Inline crypto-helper strings encoding the cipher's identifier
  (intentional concealment from competitors, not a secret).
- Specific library versions, DI choice (Hilt/Koin/Dagger),
  networking choice (Retrofit/Ktor/OkHttp), async choice
  (Coroutines/RxJava), architectural pattern (MVVM/MVI/Clean).
- File/package structure, class/method names.
- Generic Android best-practices already covered by AGP/R8 defaults.

## 4. CLAUDE.md scaffold (5 fields)

```
# Project context for Claude Code

(Free-form short description, optional.)

---

# Android Review configuration

## project-type

with-attribution           # auto-detected: with-attribution | no-attribution

## landing-mechanism

webview                    # auto-detected: webview | custom-tabs | none

## redirect-method

# TODO: Choose one of:
#   - 7.1 webMessageListener
#   - 7.2 consoleLog
#   - 7.3 shouldOverrideUrlLoading
# Plugin verifies ONLY this method's correctness.
# Leave empty if landing-mechanism = none or custom-tabs.

## backend-domain

https://domain.store       # auto-detected if a unique URL is found, else TODO

## accepted-deviations

# rule-id: justification
# Each non-comment line silences the named functional check with a
# written reason. Comments (#-prefixed) are ignored by the parser.
```

### 4.1. Auto-detection in `/android-review:android-review-init`

- **`project-type`**: read `gradle/libs.versions.toml` and
  `app/build.gradle.kts`. If any of OneSignal /
  `installreferrer` / `play-services-ads-identifier` is declared
  → `with-attribution`. Else → `no-attribution`.
- **`landing-mechanism`**: glob `app/src/main/java/**` for
  `WebView(` constructor or `findViewById<WebView>` AND for
  `CustomTabsIntent`. Only WebView → `webview`. Only CustomTabs
  → `custom-tabs`. Both → TODO. Neither → `none`.
- **`backend-domain`**: grep for HTTPS URLs in string literals
  matching common production-domain TLDs (`.store`, `.app`, `.io`,
  `.dev`, `.com`). If exactly one unique non-localhost URL found →
  auto-fill. Else → TODO.
- **`redirect-method`** and **`accepted-deviations`**: TODO for the
  human, plugin cannot guess.

### 4.2. Refusal to overwrite

If `.claude/CLAUDE.md` already exists, `/android-review-init` aborts
without overwriting (same behavior as v1.x). To regenerate,
delete the file first.

## 5. Report format

```
# Android Review — <project-id>

**Дата:** <YYYY-MM-DD HH:MM>  •  **Тип проєкту:** with-attribution | no-attribution
**Лендинг:** webview | custom-tabs | none  •  **Метод редіректу:** 7.X | n/a

## Вердикт: ✅ ГОТОВО | ⚠️ З ЗАСТЕРЕЖЕННЯМИ | 🔴 НЕ ГОТОВО

---

## 🔴 Критичні баги функціональної логіки

(per-finding: which invariant is broken, what specifically is wrong,
where in the code the plugin found the evidence, how to fix)

---

## ⚠️ Підозрілі патерни

(things worth a look but not release-blockers)

---

## ℹ️ Спостереження

(informational, may be empty)

---

## 📋 Перевірені інваріанти

✅ <invariant 1>
✅ <invariant 2>
...

(green-checkmark list of every check that passed — gives the developer
visibility into what the plugin actually verified, not just what it
flagged)

---

## Пропущені перевірки

- <check-id> — <reason>, e.g. "no-attribution project type, OneSignal-flow checks skipped"
```

### 5.1. Verdict computation

- 0 critical, 0 suspicious → `✅ ГОТОВО`.
- 0 critical, ≥1 suspicious → `⚠️ З ЗАСТЕРЕЖЕННЯМИ`.
- ≥1 critical → `🔴 НЕ ГОТОВО`.

### 5.2. Severity philosophy

Three levels, named in domain language:
- **Критичні баги функціональної логіки** — invariants from §3
  that, if broken, cause runtime issues or violate the user-defined
  contract. Especially `flow/organic-routing-critical`.
- **Підозрілі патерни** — non-critical heuristics worth a glance.
- **Спостереження** — informational, never blocks.

The v1.x style/security/obfuscation category split is removed
entirely — it doesn't map to functional flows.

### 5.3. Terminal output

A compact summary identical to the file header + verdict + counts +
saved-paths. The full report stays in the saved `.md` file.

### 5.4. Localization

Ukrainian for all human-readable text. Rule IDs and severity tokens
stay English (machine-readable).

## 6. Files

- Single output: `.claude/reports/<project-id>-android-review.md`.
- Previous report rotated to
  `.claude/reports/archive/<project-id>-<YYYY-MM-DD-HHmm>.md` on
  each new run.
- `.gdoc.txt` second-format output is removed entirely. If the user
  needs Google Docs ingest, they paste `.md` directly into a Doc
  (modern Google Docs handles markdown paste reasonably). A separate
  upload-to-Drive command can be added later as a separate milestone.

## 7. Slash commands

Two commands total. The three v1.x specialized commands
(`-style`, `-security`, `-obfuscation`) are removed.

- `/android-review:android-review` — full functional review,
  produces saved `.md` + compact terminal summary.
- `/android-review:android-review-init` — creates the new 5-field
  `.claude/CLAUDE.md` scaffold with auto-detection.

## 8. Internal architecture

- **Single cohesive agent** named `functional-validator`. The 3
  v1.x sub-agents (style/security/obfuscation) are removed.
- **No orchestrator sub-agent.** Orchestration runs in the slash
  command body (proven pattern from v1.5.0 — top-level Claude has
  Task tool, sub-agents do not).
- **One Task call** to dispatch `functional-validator` with the
  plugin root path injected (same runtime auto-detection mechanism
  as v1.5.0: `ls -td "$HOME/.claude/plugins/cache/android-review-marketplace/android-review/"*/`).
- **context7 MCP integration retained** as the knowledge-currency
  check before flagging any finding tied to Android-ecosystem
  behavior.
- **Tools** for the agent:
  `Read, Glob, Grep, mcp__plugin_context7_context7__query-docs,
  mcp__plugin_context7_context7__resolve-library-id`.
- **Tools** for the slash command body:
  `Read, Glob, Grep, Bash, Write, Task`.

## 9. Rules — new catalog

The 21 v1.x rules (style/security/obfuscation/cross-cutting) are
deleted in full. v2.0 ships ~7-10 functional rules under a single
new directory layout:

```
rules/
  flow/
    initial-startup-checklist.md
    uuid-persistence.md
    organic-routing-critical.md
    non-organic-post-required.md
    redirect-method-correctness.md
  webview/
    config-completeness.md
    activity-fullscreen-orientation.md
  crypto/
    post-data-encoding-pattern.md
  _schema.md
  _template.md
```

Per-rule severity:
- `flow/organic-routing-critical` → **critical** (the §3.6 invariant).
- `flow/initial-startup-checklist`, `flow/uuid-persistence`,
  `flow/non-organic-post-required`,
  `flow/redirect-method-correctness`,
  `webview/config-completeness`,
  `webview/activity-fullscreen-orientation`,
  `crypto/post-data-encoding-pattern` → **suspicious** by default;
  promoted to **critical** if the agent has high confidence the
  behavior is genuinely broken (not just unusual).

### 9.1. Rule file format

The v1.x frontmatter (`id`, `severity`, `category`, `applies-to`,
`since`) survives but with adjustments:

- `category` becomes `flow | webview | crypto` (no
  style/security/obfuscation).
- `applies-to` becomes optional and acts as a hint for the agent's
  attention, not a hard pre-filter (the agent does dataflow tracing,
  not grep over `applies-to` patterns).
- New optional `requires-project-type` field — e.g.,
  `requires-project-type: with-attribution` causes the rule to
  auto-skip on `no-attribution` projects.

Body sections:
- `## Інваріант` — what behavior must hold.
- `## Як перевірити` — dataflow-trace recipe for the agent.
- `## Як виглядає поломка` — minimal example of the broken behavior.
- `## Як виглядає правильно` — minimal example of correct behavior.
- `## Як доповідати` — exact finding template (Ukrainian body).
- `## Виключення` — when the user can silence via
  `accepted-deviations`. Use `Жодних` if it cannot be silenced
  (reserved for `flow/organic-routing-critical`).

## 10. Out-of-scope explicit list (rules NOT carried over from v1.x)

These v1.x rules are deleted with no replacement:

- `style/kotlin-naming-conventions`
- `style/compose-stable-parameters`
- `style/hilt-no-field-injection`
- `style/required-libraries-present`
- `style/webp-images`
- `style/adaptive-icon`
- `style/orientation-config`
- `security/no-cleartext-traffic`
- `security/no-hardcoded-secrets`
- `security/exported-component-without-permission`
- `security/manifest-cleanup-third-party-permissions`
- `security/release-logs-disabled`
- `security/custom-user-agent-not-default`
- `security/splash-attribution-flow` (replaced by
  `flow/initial-startup-checklist` + `flow/organic-routing-critical`
  with corrected semantics)
- `obfuscation/crypto-classes-keep-rules-present`
- `obfuscation/seed-keys-not-plain-string`
- `obfuscation/minify-enabled-in-release`
- `obfuscation/shrink-resources-enabled`
- `obfuscation/encrypted-sharedpreferences-for-uuid`
- `obfuscation/strings-xml-no-sensitive`
- `cross/exported-component-not-keep`

The agent prompts, sub-agent files, and command files for v1.x are
also deleted (see §11).

## 11. Migration from v1.x

- Delete `rules/` entirely; recreate with the v2.0 catalog from §9.
- Delete `agents/{style,security,obfuscation}-auditor.md`. Create
  `agents/functional-validator.md`.
- Delete `commands/android-review-{style,security,obfuscation}.md`.
- Rewrite `commands/android-review.md` to dispatch the single new
  agent and to produce the new report shape.
- Rewrite `commands/android-review-init.md` for the 5-field
  scaffold with new auto-detection logic.
- Update `examples/good-claude-md-for-project.md` to the new shape.
- Delete `examples/good-proguard-rules.pro` (no longer relevant).
- Update `docs/project-claude-md-template.md` for the 5-field
  reference.
- Update `docs/how-to-add-a-rule.md` for the new rule body sections
  (`## Інваріант` etc.).
- Update `docs/smoke-test.md` for v2.0 expected outputs.
- Bump version: `1.5.0` → `2.0.0` in
  `.claude-plugin/plugin.json` and `marketplace.json`.
- CHANGELOG entry for `2.0.0` honestly explaining the philosophy
  shift, the rule deletions, and the migration story.
- Tag `v2.0.0`. v1.x stays accessible via Git history (`git checkout v1.5.0`).

## 12. Verification

The acceptance bar is "user says the report is something he'd send
to a developer" on at least 2 real team projects.

End-to-end smoke test plan:

1. **Init smoke** — on a fresh project without `.claude/CLAUDE.md`,
   run `/android-review:android-review-init`. Confirm the new
   5-field scaffold lands, with `project-type`/`landing-mechanism`/
   `backend-domain` auto-detected (the latter when a unique URL is
   detectable).
2. **Run smoke (with-attribution)** — on a real
   `with-attribution` project, run `/android-review:android-review`.
   Confirm:
   - Header shows correct project-type/landing-mechanism/redirect-method.
   - Report has 3 severity sections (Critical/Suspicious/Observation).
   - "Перевірені інваріанти" section lists every passed check.
   - "Пропущені перевірки" lists skipped rules with reason.
3. **Run smoke (no-attribution)** — on a `no-attribution` project,
   confirm `flow/initial-startup-checklist`,
   `flow/organic-routing-critical`,
   `flow/non-organic-post-required` are skipped with reason
   "no-attribution project type".
4. **Critical-bug detection smoke** — synthetically mutate a real
   project to send organic users straight to game (bypass WebView).
   Confirm `flow/organic-routing-critical` fires as critical and
   verdict becomes `🔴 НЕ ГОТОВО`.
5. **Refusal smoke** — `cd /tmp; /android-review:android-review` →
   confirm exact two-line abort message in English (same hard-abort
   discipline as v1.x).
6. **Acceptance** — user reads the saved `.md` from steps 2-3 and
   says "yes, this is sendable".

## 13. Decisions log

| Decision | Choice | Why |
|---|---|---|
| Validation philosophy | Functional, not structural | v1.x noise was caused by structural pinning; the team's apps converge on behavior, not structure |
| Categories | Flat (`flow`/`webview`/`crypto`), no severity-by-category | Style/security/obfuscation didn't match how the team triages |
| Number of agents | One (`functional-validator`) | 3-agent split was a v1.x artifact of the structural model; functional flows don't split cleanly |
| Orchestrator sub-agent | Dropped (orchestration in command body) | Confirmed in v1.5.0 that Task isn't available inside sub-agents; command body works |
| context7 MCP | Retained | Knowledge-currency check is independently valuable |
| Output formats | `.md` only | `.gdoc.txt` was rarely needed; markdown paste into Google Docs handles modern Docs reasonably; a separate Drive-upload command can be added later |
| Slash commands | 2 (full + init) | Specialized -style/-security/-obfuscation lose meaning in functional model |
| CLAUDE.md fields | 5 (3 auto-detected) | v1.x had 6 mostly-unused fields; 5 functional fields with smart defaults |
| Severity scheme | 3 levels with domain names | "Критичні баги/Підозрілі/Спостереження" reads naturally; "errors/warnings/info" was generic |
| New section "Перевірені інваріанти" | Yes | Developer needs to see what passed, not only what failed |
| Localization | Ukrainian for human text, English for tokens | Same as v1.x post-1.2.0 |
| Migration | Hard cutover; v1.x stays in Git history | Trying to incremental-migrate would prolong the broken-feeling state |
| Versioning | v2.0.0 | Major bump signals contract change to anyone pinning version |
