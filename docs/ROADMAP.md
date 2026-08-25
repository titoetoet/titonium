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
- Launcher, Application Catalog and Dashboard — reopening for profile identity, fixed 1/3–2/3
  composition, Favorites/Recent, 6×4 horizontal paging and confirmed session actions.
- Active Window — running-app task strip implemented adjacent to Workspaces; awaiting interactive
  activation and focus-transition acceptance.
- Clock — lazy analog-clock panel implemented; Calendar remains available for the future
  Notification Center rather than the clock trigger. Awaiting visual acceptance.

## Milestone 2 — Theme Engine and Settings Center — Complete

- Settings shell, Theme/Typography pages and Preview/Apply/Cancel — approved and complete.
- Panel/Layout and Frame scoped-reset flow — complete.
- Audio, System and Launcher settings — complete; expensive runtime features remain owned by their later module phases.
- Hybrid Glass package, optional one-shot hyprglass capability, QML/solid fallback and compatible-theme-only Material editor — complete.
- Preview/Apply/Cancel, appearance restore and page-scoped resets share one atomic runtime transaction; Neutral Utility remains the immutable solid baseline.

## Milestone 3 — Spotlight

Search shell with separately testable providers and lazy result views.

## Milestone 4 — Window Switcher

Safe Alt+Tab lifecycle with compositor submap recovery.

## Milestone 5 — System modules

Media/Audio/Visualizer; Wi-Fi/Bluetooth; Monitor/Status/System Info.

## Milestone 6 — Notifications and information

Notification widget/toasts/center; News/Weather cards and further extension modules.
