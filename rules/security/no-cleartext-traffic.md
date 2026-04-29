---
id: security/no-cleartext-traffic
severity: error
category: security
applies-to:
  - app/src/main/AndroidManifest.xml
  - app/src/main/res/xml/network_security_config.xml
since: "1.0.0"
---

# No cleartext traffic in release builds

## Чому це важливо

Cleartext HTTP traffic enables MITM attacks, parameter capture, and
response tampering. Google Play marks `usesCleartextTraffic="true"` as
high-severity in pre-launch reports and may reject apps that handle
sensitive flows (auth, payments, attribution) over plain HTTP. Even
when the dev believes the endpoint is internal, attackers on the same
network can intercept it.

## Що перевірити

1. In `app/src/main/AndroidManifest.xml`, the `<application>` element
   must NOT have `android:usesCleartextTraffic="true"`.
2. If `app/src/main/res/xml/network_security_config.xml` exists, it
   must NOT contain a `<base-config cleartextTrafficPermitted="true">`
   without a domain-scoped `<domain-config>` overriding it.
3. If cleartext is intentionally required (e.g., a local dev endpoint),
   it MUST be scoped via `<domain-config>` in
   `network_security_config.xml`. Per-domain scoping is the only
   acceptable workaround — this rule cannot be silenced via
   `accepted-risks`.

## Як це виглядає у поганому проекті

```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

## Як це має виглядати

```xml
<application
    ...>  <!-- attribute absent or "false" -->
```

If cleartext truly is needed for one domain, use:

```xml
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">10.0.2.2</domain>
    </domain-config>
</network-security-config>
```

## Як доповідати

```
[security/no-cleartext-traffic] ERROR
  app/src/main/AndroidManifest.xml:<line>
  android:usesCleartextTraffic="true" set on <application>.
  Fix: remove the attribute, or scope cleartext to one domain via network_security_config.xml.
  See: https://developer.android.com/training/articles/security-config
```

## Виключення

Жодних. Per-domain scoping via `network_security_config.xml` is the
only acceptable workaround.
