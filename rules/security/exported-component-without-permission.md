---
id: security/exported-component-without-permission
severity: warning
category: security
applies-to:
  - app/src/main/AndroidManifest.xml
since: "1.0.0"
---

# Exported components must declare an explicit permission boundary

## Чому це важливо

`android:exported="true"` on an Activity/Service/Receiver/Provider
makes it callable by any other app on the device. If the only "guard"
is a missing intent-filter or implicit assumption, a malicious app can
launch the component with crafted extras, exfiltrating data or
triggering privileged behavior. The launcher Activity is a known
exception (its intent-filter is the permission boundary), but every
other exported component must either (a) declare
`android:permission` referencing a signature-protected permission, or
(b) be explicitly opted in via `accepted-risks`.

## Що перевірити

1. In `app/src/main/AndroidManifest.xml`, list every
   `<activity>`/`<service>`/`<receiver>`/`<provider>` with
   `android:exported="true"`.
2. For each, check:
   a. If it is the launcher Activity (has `<action android:name="android.intent.action.MAIN" />`
      with `<category android:name="android.intent.category.LAUNCHER" />`), it is permitted.
   b. If it has `android:permission="..."`, it is permitted (but
      verify the permission's `protectionLevel` is `signature` if it
      is a custom one).
   c. Otherwise — flag.
3. Cross-reference with `accepted-risks`. If the rule's `id` appears
   there with a non-empty reason, the agent's procedure (step 4.b)
   handles suppression — this rule does not need to do anything extra
   in step 3. Just enumerate violations as `warning` findings.

## Як це виглядає у поганому проекті

```xml
<service
    android:name=".PushService"
    android:exported="true" />   <!-- no permission, not the launcher -->
```

## Як це має виглядати

```xml
<service
    android:name=".PushService"
    android:exported="true"
    android:permission="com.example.app.permission.RECEIVE_PUSH" />
```

…with a matching `<permission android:protectionLevel="signature" .../>`.

## Як доповідати

```
[security/exported-component-without-permission] WARNING
  app/src/main/AndroidManifest.xml:<line>
  <component-tag> "<name>" експортовано, але не має android:permission і це не launcher-Activity.
  Як виправити: додайте android:permission із власним signature-level дозволом, або встановіть android:exported="false", якщо компонент не споживається ззовні.
  Див.: https://developer.android.com/guide/topics/manifest/activity-element#exported
```

## Виключення

Дозволено через `accepted-risks` тільки з обґрунтуванням, що компонент
свідомо публічний (наприклад, deeplink-handler з санітизацією на вході).
Reason rule must say so explicitly.
