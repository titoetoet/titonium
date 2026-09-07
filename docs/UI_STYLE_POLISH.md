# UI style polish

The Dock page in Option Center now previews `modules.dock.style` with three values:
`follow-topbar` (default), `connected`, and `classic`. Existing v7 settings without the
field and invalid values normalize to Follow Topbar. The normal Settings Cancel and
Apply transaction owns preview rollback and persistence. The launcher follows
`modules.bar.style` directly.

Connected uses the existing `Shared.ConnectedPillShape`: the Dock attaches to the
bottom edge and the launcher attaches to the top edge. Classic uses outlined
detached surfaces. The app menu is detached in both styles, with no connector
between the popup and the Dock icon. It reads the
clicked icon's screen-local position and the Dock's published bounds, clamps to the
viewport, and scrolls on short screens. Closing is guarded by descriptor identity;
changing the Dock style releases its menu.

Notification history keeps its accessible clear-all icon and omits the close
button. Escape, outside-click and the Topbar control still dismiss history. The
active-window view animates its natural width with the existing damped easing;
Reduced Motion removes that duration. No application actions, Clipboard behavior,
Input Method integration or key bindings change.

The implementation reuses Titonium's Topbar/Shared shapes and Classic Network
popup presentation conventions. No third-party code or dependencies were added.

## Verification on 2026-09-05

- `./scripts/check.sh`: passed, including QML lint, schema/i18n, preference
  projection/migration, Dock geometry and protected Spotlight contracts.
- `./scripts/smoke.sh`: passed.
- Fresh isolated launches: inspected Connected and Classic launcher/Dock menu,
  and the Dock settings selector. Increased menu width to fit Vietnamese labels.
- Isolated theme-switch check: Notification Center releases its logical owner.
- `hyprctl configerrors`: empty. Final layer inspection found one Titonium
  instance on DP-1 and no Titonium layer on DP-3.
- `./scripts/protected_acceptance.sh`: not fully passing. The run passed Spotlight,
  Dock, Bluetooth, Wi-Fi, Window Switcher and workspace checks, then failed the
  Notification Center style-switch layer assertion. A focused rerun instead failed
  critical FIFO expiry. A Quickshell shutdown crash and duplicate retained native
  layers complicated live testing; these are not recorded as passing checks.

Remaining manual review: rapid focus changes, theme preview/Cancel/Apply, and
Reduced Motion. The temporary visual fixture invoked menu presentation without activating
any application or menu action. No automated test launched an application or wrote
the Clipboard.

## Screenshot follow-up and deployment

Removed the Dock menu connector entirely. The rounded popup stays above the Dock,
anchors to the invoking icon, and clamps to the viewport. Compact Center follows
Topbar reveal state in every theme and removes its input region while hidden;
banners and expanded interaction preserve their existing behavior.

After the connector removal, static/QML checks, smoke, and settings acceptance
passed. Protected acceptance again passed Spotlight, Dock, Bluetooth, Wi-Fi,
Window Switcher and workspace checks, then failed the Notification Center
Connected-to-Classic style-switch assertion.

Live interaction on the deployed shell verified:
- Right-clicking ChatGPT and Vesktop anchors the detached popup to each icon.
- Escape and outside-click dismiss the popup and release its focus owner.
- Clicking unpin and leaving the Topbar hides the compact Center pill.
- Moving to the top edge reveals the Topbar and compact Center together.
- Repinning keeps the compact Center visible after the pointer leaves.

The original settings were restored and compared equal to the pre-test snapshot;
the pointer was restored to its original position. Final inspection confirmed one
running instance (PID 122936), app status `ready`, Titonium layers only on DP-1,
and no Hyprland configuration errors. No application or Dock menu action was
launched during these interactions.
