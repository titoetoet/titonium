# Task 1 — Policy rules and settings schema

## Scope delivered

- Normalized immutable notification descriptors now include namespaced keys, source/application identity,
  normalized native urgency, policy severity/route/category, immutable actions, and receipt time.
- `resolvePolicy()` applies Custom application overrides before internal safety mappings, native urgency,
  and the normal fallback. Automatic mode ignores application overrides; the three internal job/timer
  safety events remain critical in every mode.
- Added the 100-history, 3-toast, and 16-critical-queue rule limits and policy settings projection for
  `policyMode`, `allowCriticalOnIsland`, `keepCriticalUnread`, and sanitized application overrides.
- Updated shipped defaults, JSON Schema, runtime fixture, configuration validation, and preference/schema
  contracts.

## RED evidence

1. `node scripts/check_notification_policy_rules.js` initially failed with
   `TypeError: rules.nativeUrgency is not a function`.
2. `node scripts/check_preferences.js` initially failed because projected notification
   `policyMode` was `undefined` instead of `automatic`.
3. `python3 scripts/check_settings_schema.py` initially rejected the custom notification policy fixture
   because all four new properties were unknown schema properties.
4. The final critical-island regression test was observed failing against the pre-fix branch:
   expected `history`, received `center` for a Custom `critical` override while the island toggle was off.

## GREEN evidence

- `node scripts/check_notification_policy_rules.js`
- `node scripts/check_notifications_rules.js`
- `node scripts/check_preferences.js`
- `python3 scripts/check_settings_schema.py`
- `python3 scripts/validate_config.py`
- `./scripts/check.sh`

All commands exited successfully after the implementation. The static gate completed with only its existing
allowlisted QML dependency warnings and ended with `PASS qmllint`.

## Concern / downstream note

`keepCriticalUnread` is normalized and persisted here; Task 3/5's coordinator owns applying it when
critical history/unread state is introduced. No native service or Center integration changed in this task.
