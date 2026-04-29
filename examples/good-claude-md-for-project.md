# Project context for Claude Code

Sample Android casual game built with Kotlin + Jetpack Compose + Hilt.
Splash queries a remote config endpoint, then either gameplay or a
WebView landing flow. AAID + OneSignal + Install Referrer integrations.

---

# Android Review configuration

## project-id

example-juicer

## expected-values

applicationId: com.example.juicer
namespace: com.example.juicer
minSdk: 26
targetSdk: 36

## critical-classes

- com.example.juicer.core.crypto.**
- com.example.juicer.data.model.**
- com.example.juicer.data.api.dto.**

## sensitive-files

- app/src/main/java/com/example/juicer/core/crypto/**
- app/src/main/java/com/example/juicer/data/api/**

## accepted-risks

# This project intentionally suppresses one rule with a written reason.
# Lines without a leading `#` are active suppressions; commented lines are ignored.
security/exported-component-without-permission: MainActivity is the launcher; intent-filter is the permission boundary

## rule-overrides

# (R3 placeholder — leave empty for M1.)
