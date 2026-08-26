# Roadmap

The previous feature roadmap is retired. Work now advances by researched capability slices.

## Baseline — complete

- Dynamic multi-monitor bar and overlay lifecycle.
- Protected Spotlight Applications/Clipboard/System mock.
- Protected event-driven Input Method.
- Temporary Workspaces and Clock.
- Application, Clipboard and Hyprland service boundaries.
- Static Neutral Utility tokens, i18n and focused gates.

## Next — joint reference-repository research

For each candidate repo, record license, revision, Quickshell version, architecture pattern,
runtime dependencies and the exact modules worth studying. Compare implementations before copying
code. The first research set should cover:

1. Hyprland Workspaces and System Tray.
2. Audio/MPRIS and reusable slider/OSD behavior.
3. Notifications and toast/center lifecycle.
4. Network/Bluetooth services only after the shared service pattern is agreed.

## Integration order

1. Replace one temporary bar widget using the selected reference pattern.
2. Add System Tray as a bounded bar module.
3. Establish animation and theme-input policy (static JSON or matugen) without coupling features.
4. Add Audio/MPRIS, then notifications, each as Service → View → live acceptance.
5. Revisit Settings only after several real modules expose stable preferences.

Spotlight and Input Method remain protected throughout. Major surfaces such as Window Switcher or
a new Settings Center require their own design and test checkpoint; they are not placeholders in
the skeleton.
