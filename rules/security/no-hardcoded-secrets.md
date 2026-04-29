---
id: security/no-hardcoded-secrets
severity: error
category: security
applies-to:
  - app/src/main/java/**/*.kt
  - app/src/main/java/**/*.java
since: "1.0.0"
---

# No plain-string secrets, seeds, or API keys

## Чому це важливо

Strings constants in Kotlin/Java compile into the APK as readable UTF-8.
Decompilers (`apktool`, `jadx`) extract them in seconds. A "hidden" AES
seed, OneSignal app id, signing salt, or backend URL stored as a plain
`const val` provides zero protection. Junk-character obfuscation
(building a string from a `charArrayOf(...)` with index picking) is
trivially reversible by any reverse-engineer with five minutes.

## Що перевірити

1. Search files matching `sensitive-files` (from project's
   `.claude/CLAUDE.md`; if missing, search all `.kt`/`.java`).
2. For each file, flag occurrences of:
   a. Plain `const val` / `val` / `String` literals 24+ chars long
      that look like Base64 (`[A-Za-z0-9+/_-]{24,}=*`) or hex
      (`[A-Fa-f0-9]{32,}`).
   b. Variables named `*_SEED`, `*Seed`, `*KEY`, `*Key`, `*SECRET`,
      `*Token`, `*PASSWORD` whose value is a plain string literal.
   c. Plain literals matching attribution endpoint patterns
      (`http://`, `https://api.`, `https://` + IP).
3. Distinguish from already-encrypted blobs (those usually pair with a
   visible AES/Base64 decryption helper). If the file imports
   `javax.crypto.Cipher` and decrypts the blob via a helper, downgrade
   to `warning` instead of `error`, but still report — the seed itself
   is the weak link.

## Як це виглядає у поганому проекті

```kotlin
// rules/security/no-hardcoded-secrets — example bad
val USER_SEED: ByteArray = "K9mT4Xq2Zp7Lw1R8Ys5Nv6Hd3Fa0BcJu".toByteArray()

object KeyGeneral {
    const val key1 = "abcd1234efgh5678..."
}
```

## Як це має виглядати

The seed must come from outside the APK: NDK-stored, server-derived,
KeyStore-bound, or split across multiple compiled artefacts whose
recombination is non-obvious. For early MVP, store in `BuildConfig`
fields populated from local `gradle.properties` (still trivial, but
removes from source) and treat the rule as "warning at minimum".

## Як доповідати

```
[security/no-hardcoded-secrets] ERROR
  <file>:<line>
  Plain-string secret/seed: <variable-name> = "<first-8-chars>...<last-4>" (<length> chars).
  Fix: do not embed seeds as compile-time string constants. Move to BuildConfig from gradle.properties at minimum, or to NDK/KeyStore for production.
  See: https://developer.android.com/privacy-and-security/keystore
```

## Виключення

Дозволено через `accepted-risks`, **тільки** якщо:
- це not a credential/secret (наприклад, public namespace prefix), і
- код містить коментар, що пояснює чому.

Інакше — заборонено.
