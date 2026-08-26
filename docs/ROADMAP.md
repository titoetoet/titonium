# Roadmap

## Milestone 0 — Foundation

Bootable config, schemas, config transactions, i18n/theme tokens, recursive layout renderer,
registry, surface coordinator and minimal multi-monitor MenuBar.

## Theme Foundation — Complete

Settings schema v2, immutable Neutral Utility, theme catalog/resolver, appearance-only Restore
and lazy Design Gallery. Future theme reminders: Cupertino Flat and Fluent Solid.

## Design Controls — Complete

- Typography, Icon and Button — complete.
- Surface, Card and Panel — complete.
- Switch, Slider and Dropdown — complete.
- Tabs and focus/accessibility audit — complete.
- Visualizer — deferred until the media phase, where its render lifecycle can be tested in context.

## Milestone 1 — MenuBar essentials — Active parity review

- Workspaces, Active Window and Input Method — approved and complete.
- Clock, Calendar and Lunar model — approved and complete.
- Arch Menu — complete. The superseded large Launcher prototype is removed; the Arch trigger now
  opens a compact text-and-icon system dropdown, Settings remains a standalone surface and every
  session action replaces the menu with a dedicated centered confirmation.
- Active Window — running-app task strip implemented adjacent to Workspaces; awaiting interactive
  activation and focus-transition acceptance.
- Clock — lazy analog-clock panel implemented; Calendar remains available for the future
  Notification Center rather than the clock trigger. Awaiting visual acceptance.

## Milestone 2 — Theme Engine and Settings Center — Complete

- Settings shell, Theme/Typography pages and Preview/Apply/Cancel — approved and complete.
- Panel/Layout and Frame scoped-reset flow — complete.
- Audio, System and Spotlight settings — complete; expensive runtime features remain owned by their later module phases.
- Hybrid Glass package, optional one-shot hyprglass capability, QML/solid fallback and compatible-theme-only Material editor — complete.
- Preview/Apply/Cancel, appearance restore and page-scoped resets share one atomic runtime transaction; Neutral Utility remains the immutable solid baseline.

## Milestone 3 — Spotlight Launcher — Complete

Keyboard-first application launcher with a categorized 5×4 browse grid and stable search-result
layout. `Super + Space` opens Applications plus calculator search; `Super + V` opens Clipboard.
The 800×≤760 surface is top-anchored below the MenuBar, its scope icon remains outside Search and
page pills reflect actual occupancy. Settings schema v5 adds global `applications.hiddenIds`;
Spotlight Settings uses the full catalog to hide or restore entries while all launch surfaces use
the shared visible projection. Category aliases improve classification without adding empty groups.
The compact Arch Menu and standalone Settings Center remain separate surfaces. File search remains
a later provider slice.

## Milestone 4 — Window Switcher

Safe Alt+Tab lifecycle with compositor submap recovery.

## Milestone 5 — System modules

Next design slice: Wi-Fi, Bluetooth and Sound status/panels. Media/Visualizer and
Monitor/Status/System Info follow as separately accepted slices.

## Milestone 6 — Notifications and information

Next design slice includes the Notification Toast lifecycle only. Notification widget/center,
News/Weather cards and further extension modules follow after its contract is accepted.
