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
