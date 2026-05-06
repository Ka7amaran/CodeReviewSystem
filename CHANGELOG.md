# Changelog

All notable changes to the `android-review` plugin will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semver](https://semver.org/).

## [2.4.0] — 2026-05-06

### Added

- New rule `flow/post-redirect-no-return` (severity: **critical**).
  Verifies that after the Privacy Policy → game redirect, the
  back-stack is fully cleared so the user cannot navigate back to
  the WebView landing via the BACK button / system back-gesture.
  Two acceptable forms: `navController.navigate(...)` with
  `popUpTo(graph) { inclusive = true }` (or `popUpTo(0)`), or
  `startActivity(GameActivity)` followed by `finish()`. Anything
  that leaves the WebView route in the back-stack → CRITICAL.
  Allowed via `accepted-deviations` only if the game UI provides a
  dedicated "open Privacy Policy again" button.

### Fixed

- Functional-validator agent now FORBIDDEN from emitting "please
  confirm" / "varto perekonatys'" / "verify with the team" findings.
  Such findings shifted judgment back to the human even when the
  rule body already specified a concrete contract. New hard
  constraint: every finding must describe a concrete violation; if
  the value matches the rule's canonical → silent pass.
- `webview/config-completeness` makes the canonical
  `mixedContentMode = 0` explicit: value `0` (or
  `MIXED_CONTENT_ALWAYS_ALLOW` constant) → silent pass. Values `1`
  / `2` → SUSPICIOUS with concrete diff. Missing → SUSPICIOUS as
  before.
- `webview/activity-fullscreen-orientation` no longer speculates
  about hypothetical orientation-lock leakage when the user
  "theoretically returns from game to WebView". That return path is
  itself forbidden by the new `flow/post-redirect-no-return` rule —
  if the back-stack is correctly cleared, leakage is impossible by
  construction. The rule now stays focused on its real contract:
  manifest `screenOrientation` and top-status-bar visibility.

### Notes

The plugin now ships **13 functional rules**: 6 `flow/*`, 2
`webview/*`, 1 `crypto/*`, 3 `perf/*` (+ 1 new flow rule from this
release).

## [2.3.0] — 2026-05-06

### Changed — `webview/config-completeness` evidence-based rewrite

The 20+ item canonical preset is split into three groups:

**Core (always required)** — flag SUSPICIOUS if missing:
- `mixedContentMode = 0`, `javaScriptEnabled`, `domStorageEnabled`,
  `webViewClient`, `webChromeClient`, cookie acceptance
  (`setAcceptCookie` + `setAcceptThirdPartyCookies`).

**Use-case-conditional** — flag SUSPICIOUS only when manifest
provides evidence the use-case applies:
- `onShowFileChooser` override → required only when
  `AndroidManifest.xml` declares `CAMERA`, `READ_MEDIA_IMAGES`, or
  `READ_EXTERNAL_STORAGE` (project actually allows file/photo upload
  through WebView).
- `onPermissionRequest` override → required only when manifest
  declares `CAMERA` or `RECORD_AUDIO`.

**Removed from rule** — no Android-side detection possible (depend on
backend HTML, not Android code) or already covered by other rules:
- `setDownloadListener` — depends on whether landing page exposes
  downloadable resources (PDF, APK-update). QA-test responsibility.
- `onShowCustomView` — depends on whether landing page uses HTML5
  fullscreen video.
- `setSupportMultipleWindows(true)` — depends on whether HTML uses
  `target="_blank"` / `window.open(...)`.
- `cacheMode = LOAD_DEFAULT`, `setLayerType(LAYER_TYPE_HARDWARE)` —
  performance-related, already covered by `perf/webview-pitfalls`.
- `loadsImagesAutomatically`, `useWideViewPort`, `loadWithOverviewMode`,
  `allowFileAccess`, `allowContentAccess`, `builtInZoomControls`,
  `displayZoomControls`, `javaScriptCanOpenWindowsAutomatically`,
  `databaseEnabled`, `importantForAutofill` — UX choices, default
  values, or deprecated. Not flagged.

### Why

In v2.0–v2.2 every missing preset item produced a SUSPICIOUS finding
regardless of whether the project actually used the corresponding
feature. Reports for upload-only WebView projects were noisy with
download-related findings (`setDownloadListener` etc.) that weren't
real issues. The evidence-based rewrite drops those entirely or
gates them on manifest signals.

### Notes

The plugin still ships **12 functional rules**. No rules added or
removed in v2.3 — only the surface of `webview/config-completeness`
shrank.

## [2.2.0] — 2026-05-06

### Changed — CLAUDE.md schema collapsed from 5 fields to 2

Three of the five v2.0/v2.1 CLAUDE.md fields are now **detected from
code automatically** by the validator's new **Stage 0 detection**
phase:

- `landing-mechanism` ← detected via `WebView(` /
  `AndroidView { factory = { WebView` vs `CustomTabsIntent` markers in
  `app/src/main/java/**/*.{kt,java}`.
- `redirect-method` ← detected via three signatures: `addWebMessageListener`
  (7.1), `onConsoleMessage` override on `WebChromeClient` (7.2),
  `shouldOverrideUrlLoading` + custom-scheme literal (7.3).
- `backend-domain` ← discovered as the POST endpoint URL in the
  non-organic branch (literal URL OR `<encrypted-at-rest>` for the
  team's standard runtime-decrypt pattern).

The remaining two fields are user-controlled and stay manual:
`project-type` (auto-filled at init) and `accepted-deviations`
(empty by default, only edit when silencing a finding).

This eliminates two recurring false-positives in v2.1.0 reports:
`flow/redirect-method-correctness` complaining about empty
`redirect-method` declaration when the implementation was clearly
present in code, and `flow/non-organic-post-required` complaining
about empty `backend-domain` when the URL was encrypted at rest (a
deliberate team pattern).

### Changed — `flow/redirect-method-correctness` severity escalated

Promoted from `suspicious` to `critical` and rewritten:
- 0 methods detected (with WebView present) → CRITICAL — Privacy
  Policy cannot send the user into the game.
- 2+ methods detected → SUSPICIOUS — redundant code, pick one.
- Exactly 1 detected → verify its correctness as before.

### Changed — `flow/non-organic-post-required` decoupled from backend-domain

The rule no longer cross-checks the POST URL against any declared
domain. Detection of a POST in the non-organic branch with a body
containing `{uuid, ref, adId}` is sufficient. Encrypted-at-rest URLs
are an expected team pattern and never trigger findings.

### Changed — `/android-review-init` simplified

Steps 4 and 5 (autodetect of `landing-mechanism` and `backend-domain`)
removed. Init now only auto-fills `project-type` and writes the
2-field scaffold. Faster init, fewer fields to read.

### Migration

Existing v2.0/v2.1 `.claude/CLAUDE.md` files keep working — the
validator simply ignores the three obsolete sections. To trim them,
delete `## landing-mechanism`, `## redirect-method`, and
`## backend-domain` blocks manually, or regenerate via:

```
rm .claude/CLAUDE.md && /android-review-init
```

### Notes

The plugin still ships **12 functional rules** (5 `flow/*`, 2
`webview/*`, 1 `crypto/*`, 3 `perf/*`). No rules added or removed in
v2.2 — only the contract surface shrank.

## [2.1.0] — 2026-05-06

### Added

- New rule `flow/custom-user-agent-required` (severity: **critical**,
  cannot be silenced via `accepted-deviations`). Verifies that every
  HTTP client (Ktor / OkHttp / Retrofit / HttpURLConnection) which
  calls the backend has an explicitly configured User-Agent. Default
  SDK fingerprints (`Ktor client`, `okhttp/X.Y.Z`) are flagged as a
  critical bug — backend attribution systems often filter these as
  bot-traffic. Promoted from a sub-clause of
  `flow/non-organic-post-required` where it was tagged `suspicious`
  in v2.0.0; team policy is fixed and exception-free.
- New rule category `rules/perf/` (severity: **observation** only —
  never blocks the verdict). Surfaces actionable improvements rather
  than enforcing contracts:
  - `perf/startup-blocking` — synchronous blocking ops on the main
    thread during cold-start (sync SharedPreferences read, AES init,
    JSON parse, `InstallReferrerClient` without timeout, `sleep`).
  - `perf/webview-pitfalls` — six common WebView UX/perf pitfalls
    (cookies cleared each launch, hardware accel off, cache
    disabled, file-upload without progress indicator, camera
    permission requested too early, `WebView.destroy` missing).
  - `perf/runtime-decrypt-cost` — uncached `.dec(...)` calls on the
    hot path; suggests `by lazy` caching or compile-time decrypt
    via `BuildConfig`.

### Changed

- `flow/non-organic-post-required` no longer references User-Agent.
  The UA section was removed from `## Інваріант`, `## Як перевірити`
  Step 4, and the report template — replaced with a one-line
  cross-reference to the new dedicated rule.
- `rules/_schema.md` Categories section documents `perf/` with the
  observation-only constraint.

### Notes

The plugin now ships **12 functional rules** total: 5 `flow/*`
(critical), 2 `webview/*`, 1 `crypto/*`, 3 `perf/*` (observation).
v2.1.0 is a minor bump — no breaking changes; existing CLAUDE.md
files keep working as-is.

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

## [1.5.0] — 2026-05-01

### Added (7 new rules from team checklist — batch B)

- `style/webview-config-completeness` (warning) — checks WebView
  setup for JavaScript, DOM/Database storage, third-party cookies,
  `WebChromeClient.onShowFileChooser`/`onPermissionRequest`/
  `onShowCustomView`, `setDownloadListener`, and
  `shouldOverrideUrlLoading`. One finding per missing config per
  WebView instance.
- `security/custom-user-agent-not-default` (warning) — flags Ktor /
  OkHttp / HttpURLConnection clients without an explicit User-Agent
  override. Recommends `System.getProperty("http.agent") ?: "Android"`.
- `style/webp-images` (info) — flags PNG/JPG drawables > 50 KB that
  could be converted to WebP for APK-size reduction.
- `style/adaptive-icon` (info) — flags missing
  `mipmap-anydpi-v26/ic_launcher.xml` (adaptive icon) and missing
  `<monochrome>` layer (themed icon for Android 13+).
- `security/splash-attribution-flow` (warning) — checks splash flow
  for the team's standard 7-step attribution sequence: UUID lookup
  → UUID generation → OneSignal init → OneSignal login →
  InstallReferrer → AdvertisingId → POST to backend. One finding
  per missing step.
- `obfuscation/strings-xml-no-sensitive` (warning) — scans
  `res/values/strings.xml` for sensitive patterns (URLs, OneSignal
  app id, JWT, base64 keys). Suggests BuildConfig migration.
- `style/orientation-config` (warning) — checks Activity
  `android:screenOrientation` consistency with the team's policy:
  fixed orientation for game Activities, free orientation for
  WebView/policy/auth Activities.

### Notes

The plugin now ships **17 rules** total (5 style + 5 security + 7
obfuscation, where `proguard-rules-not-empty` was removed in v1.2.2
and `strings-xml-no-sensitive` is technically obfuscation-flavored
but security-adjacent).

Items from the team's checklist that remain manual (no static rule
yet, recommended for runtime/QA verification):
- Privacy Policy → game redirect (4 navigation methods to test).
- Git branch strategy (with-attribution vs without-attribution).
- WebView OAuth flows for Google/Facebook/Apple (require live test).
- WebView payment flows (require live test).

## [1.4.0] — 2026-05-01

### Added (5 new rules from team checklist)

- `security/manifest-cleanup-third-party-permissions` (warning) —
  flags missing `tools:node="remove"` for the standard list of
  vendor permissions that bleed in via SDK manifest-merge
  (BIND_GET_INSTALL_REFERRER_SERVICE, WAKE_LOCK,
  RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE, vendor badge-permissions
  for Samsung/HTC/Sony/Huawei/Oppo/Apex/Solo/Everything etc).
- `security/release-logs-disabled` (warning) — flags `Log.d/v/i` and
  `println(...)` not guarded by `BuildConfig.DEBUG` and not stripped
  via `-assumenosideeffects` ProGuard rule. Body in saved files
  presents both fix options (code-level guard or ProGuard strip).
- `obfuscation/minify-enabled-in-release` (warning) — flags release
  buildType without `isMinifyEnabled = true`.
- `obfuscation/shrink-resources-enabled` (info) — flags release
  buildType without `isShrinkResources = true` (also flags if it's
  set but `isMinifyEnabled` is false).
- `style/required-libraries-present` (info) — flags missing OneSignal,
  Install Referrer, or Play Services Ads Identifier in
  `libs.versions.toml`/`build.gradle.kts`. Suggests `accepted-risks`
  declaration for "no-attribution" branch builds.
- `obfuscation/encrypted-sharedpreferences-for-uuid` (info) — flags
  `SharedPreferences` usage for UUID/token storage that's not
  `EncryptedSharedPreferences`. Suggests
  `androidx.security:security-crypto` migration.

### Changed

- All 3 audit sub-agents now have a mandatory **Output language
  constraint** that forces every human-readable text in findings,
  skipped reasons, and accepted-risks annotations to be Ukrainian.
  Rule IDs, severity tokens, code identifiers, and structural section
  headers stay English (machine-readable). This addresses
  inconsistent localization in v1.2.0–v1.3.0 reports.

### Notes for further iteration

The team's full Code Review checklist contains additional items not
yet covered by static rules:
- WebView config completeness (JavaScript, DOM Storage, third-party
  cookies, file upload, fullscreen video).
- Custom User-Agent for HTTP clients (not default ktor/okhttp).
- WebP for `res/drawable*`, adaptive icon manifest.
- Splash UUID + OneSignal init + InstallReferrer attribution flow.
- Privacy Policy → game redirect navigation strategy verification.
- Git branch strategy (with-attribution vs without-attribution).

These will be added in subsequent releases as concrete static rules
where statically checkable, and as a manual checklist where they
require runtime testing (navigation flow, payment flow, file upload).

## [1.3.0] — 2026-05-01

### Added

- **context7 MCP integration in all 3 audit sub-agents** (style,
  security, obfuscation). Each agent now has a mandatory
  "Knowledge-currency check" step: before emitting any finding tied
  to Android-ecosystem behavior, the agent consults the `context7`
  MCP server (via `query-docs` and `resolve-library-id` tools) to
  verify the rule's claim is still accurate against the latest
  stable versions of the relevant library/framework (AGP, R8,
  Hilt, kotlinx.serialization, Compose, etc).
- If context7 confirms the rule is outdated, the agent skips the
  finding and lists the rule under `### Skipped rules` with the
  context7 quote as reason.
- If context7 is inconclusive/unavailable, the agent fails open:
  emits the finding as written, but tags it `(context7: inconclusive)`.

This addresses the broader concern that the rule library may drift
from ecosystem reality. Reports now reflect the current state of
Android/Kotlin/library behavior, not the state when the rule was
first authored.

### Requirements

The `context7` MCP server must be installed in the user's Claude
Code environment (it ships with the official `claude-plugins-official`
plugin set). If absent, agents fail open.

## [1.2.2] — 2026-05-01

### Removed

- Rule `obfuscation/proguard-rules-not-empty`. The rule fired ERROR
  whenever `isMinifyEnabled=true` and `app/proguard-rules.pro` had no
  custom keep rules. In modern Android stacks (AGP 8.x, R8 8.x with
  Hilt/kotlinx.serialization/Compose/Ktor), the libraries' own
  consumer-rules are picked up automatically — an empty user
  proguard-rules.pro is genuinely fine for typical projects.
  Real coverage gaps for projects that DO use reflection are still
  caught by `obfuscation/crypto-classes-keep-rules-present` (which
  fires only when `critical-classes` is declared and not covered).

## [1.2.1] — 2026-05-01

### Changed

- TODO comments in the `.claude/CLAUDE.md` scaffold (generated by
  `/android-review:android-review-init`) rewritten to be honest about
  WHEN the section needs to be filled and WHEN it can be left empty:
  - `critical-classes` is labeled OPTIONAL with a clarifier that
    modern Android stacks (Hilt + kotlinx.serialization + Compose +
    Ktor) usually don't need it — those libraries ship their own
    consumer-rules in the AAR. The TODO now lists three concrete
    reflection-use-site examples (`Class.forName(...)`,
    `KClass.simpleName` as map key, custom string-name JSON
    serializer) as the actual triggers for filling the section.
  - `sensitive-files` is labeled OPTIONAL with a clarifier that the
    security auditor already scans every Kotlin/Java file by default;
    the section just narrows the focus on large codebases.
- `docs/project-claude-md-template.md` Section reference table
  matches the new framing — both rows downgraded from `Recommended`
  to `Optional`, with a one-paragraph explainer.

## [1.2.0] — 2026-04-30

### Changed

- **Ukrainian localization** for all user-facing report content:
  - Section headers in saved markdown report and in compact terminal
    summary (`Errors (must fix)` → `Помилки (обов'язково виправити)`,
    `Warnings (recommended)` → `Попередження (рекомендується)`,
    `Cross-cutting findings` → `Перехресні знахідки`, etc.).
  - Verdict labels (`READY` → `ГОТОВО`, `NOT READY` → `НЕ ГОТОВО`,
    `INCOMPLETE` → `НЕПОВНИЙ ПРОГІН`).
  - Summary table column and row labels (`Category`/`Errors`/...
    → `Категорія`/`Помилки`/`Попередж.`/`Інфо`/`Пропущ.`,
    `Style`/`Security`/`Obfuscation`/`Total` → `Стиль`/`Безпека`/
    `Обфускація`/`Усього`).
  - CLAUDE.md status (`found ✓` → `знайдено ✓`, `missing ⚠️` →
    `відсутній ⚠️`).
  - Header field names (`Date` → `Дата`, `Plugin version` →
    `Версія плагіна`, `Project` → `Проєкт`, `Saved` → `Збережено`).
  - Run details labels (`rules applied` → `правил застосовано`,
    `findings` → `знахідок`, `Total wall-clock` → `Загальний час`).
  - Finding-body prose for all 9 rules + cross-cutting + synthesized
    plugin findings (`Fix:` → `Як виправити:`, `See:` → `Див.:`).
- Rule IDs and severity tokens (`[security/no-cleartext-traffic] ERROR`)
  remain English — they are stable machine-readable identifiers.

### Fixed

- **gdoc.txt readability:** code-fenced blocks (triple-backtick) are
  now stripped entirely from the Google-Docs-friendly output, with a
  blank line before/after the unfenced body. Previously the literal
  ` ``` ` markers were preserved, making the file unreadable when
  pasted into Google Docs.
- **Findings separator:** exactly one blank line between successive
  finding entries in the gdoc.txt for skim-readability.

## [1.1.1] — 2026-04-30

### Changed

- Sync plugin description across `plugin.json` and `marketplace.json`.
  Both now read: "Automated code review for Android projects.
  Orchestrator + 3 parallel sub-agents reading declarative markdown
  rules."

## [1.1.0] — 2026-04-30

### Added

- New slash command `/android-review:android-review-init` —
  initializes `.claude/CLAUDE.md` scaffold for the current Android
  project. Auto-fills `project-id`, `applicationId`, `namespace`,
  `minSdk`, `targetSdk` from `app/build.gradle(.kts)`. Leaves
  placeholder TODOs for `critical-classes` and `sensitive-files` for
  the user to fill in. Also appends `.claude/reports/` to the
  project's `.gitignore`.
- Refuses to overwrite if `.claude/CLAUDE.md` already exists.
- README: full Quickstart section walking through init → fill TODOs →
  full review.

### Changed

- README: command list now uses fully-qualified names
  (`/android-review:android-review` etc.).

## [1.0.1] — 2026-04-30

### Fixed

- **Portability:** plugin root is now auto-detected at runtime via
  `ls -td "$HOME/.claude/plugins/cache/android-review-marketplace/android-review/"*/ | head -1`
  in all 4 slash commands. Replaces the previous hardcoded
  `/Users/mac/CodeReviewSystem` path that broke on any other machine.
  The plugin is now installable on any Mac/Linux via `github:Ka7amaran/CodeReviewSystem`.

## [1.0.0] — 2026-04-30

### Added

- Initial MVP release.
- Slash command `/android-review` (orchestration runs in command body —
  Claude Code 2.1.x forbids `Task` from inside a sub-agent).
- Three standalone sub-agent commands: `/android-review-style`,
  `/android-review-security`, `/android-review-obfuscation`.
- Nine starter rules (3 per category):
  - **style**: kotlin-naming-conventions, compose-stable-parameters,
    hilt-no-field-injection.
  - **security**: no-cleartext-traffic, no-hardcoded-secrets,
    exported-component-without-permission.
  - **obfuscation**: proguard-rules-not-empty,
    crypto-classes-keep-rules-present, seed-keys-not-plain-string.
- Project-level `.claude/CLAUDE.md` template with `project-id`,
  `expected-values`, `critical-classes`, `sensitive-files`,
  `accepted-risks` sections (R3 `rule-overrides` placeholder reserved).
- Auto-detect fallback for `critical-classes` when CLAUDE.md is missing.
- Cross-cutting check `cross/exported-component-not-keep` (FQCN
  canonicalization through manifest's `package=`).
- Dual-format report output: `<project-id>-android-review.md` and
  `<project-id>-android-review.gdoc.txt` saved to
  `.claude/reports/` with stable name + `archive/` history.
- Compact terminal summary (table + verdict + counts + saved-paths);
  full report stays in saved files.
- Marketplace manifest (`.claude-plugin/marketplace.json`) for local
  install.

### Notes

- Plugin root path is hardcoded to `/Users/mac/CodeReviewSystem` for
  local install. Replace with the actual path or revisit with a
  marketplace-source mechanism when published to GitHub.
- Smoke-test pass on 2026-04-30 against `Juice-Master-Factory` and
  `Joker-Speed-Seven`: S1 ✓, S2 ✓, S3 ✓, S4 ✓, S5 ⚠️ (graceful
  fallback design verified architecturally; full `missing ⚠️` header
  re-run skipped — see `docs/smoke-test.md`).
