# Good ProGuard rules — minimal, working baseline for an Android Kotlin/Compose/Hilt app.
# Adjust the package roots to match your project; see comments inline.

# ---- Crash readability ----
# Keep line numbers so stacktraces are useful, but rename source files for size.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ---- Hilt / Dagger ----
-keep,allowobfuscation,allowshrinking class dagger.hilt.** { *; }
-keep,allowobfuscation,allowshrinking class * extends dagger.hilt.android.internal.managers.ViewComponentManager$FragmentContextWrapper

# ---- kotlinx.serialization ----
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class * {
    *** Companion;
}
-keepclasseswithmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}

# ---- Project: critical classes (replace package roots with yours) ----
# These classes are accessed reflectively by your decryption layer.
# R8 must NOT rename them.
# Pull this list from .claude/CLAUDE.md `critical-classes`.
-keep class com.example.app.core.crypto.** { *; }
-keep class com.example.app.data.model.** { *; }

# ---- Activities (intent-filter resolution by name) ----
-keep class com.example.app.ui.activity.MainActivity { *; }

# ---- Compose runtime markers ----
# Compose handles its own keep rules via its compiler plugin; do not duplicate.

# ---- What -keep cannot save ----
# A plain-string AES seed in source is decompilable in seconds regardless of
# any keep rule. Move seeds out of compile-time constants — see the rules
# obfuscation/seed-keys-not-plain-string and security/no-hardcoded-secrets.
