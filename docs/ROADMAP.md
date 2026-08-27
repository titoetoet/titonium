# Roadmap

The previous feature roadmap is retired. Work now advances by researched capability slices.

## Baseline — complete

- Dynamic multi-monitor bar and overlay lifecycle.
- Protected Spotlight Applications/Clipboard/System mock.
- Protected event-driven Input Method.
- Temporary Workspaces and Clock.
- Application, Clipboard and Hyprland service boundaries.
- Static Neutral Utility tokens, i18n and focused gates.
- Three independently positioned Bar islands with composed click-through regions.
- Lazy, screen-owned Center Notch with Overview and safe Tools/Session mock pages.

## Current — native capability slices

1. **Audio native slice — awaiting visual approval.** Its PipeWire owner, normalized view contract,
   popup/OSD split and read-only acceptance are implemented; mark the slice complete only after
   the two-monitor visual and interaction checklist is approved.
2. **Native Dock + Bluetooth milestone — automated acceptance complete, visual approval pending.** The
   DP-1-only Dock, native `Quickshell.Bluetooth` service, state-aware connectivity button,
   lazy popup, pure rules and static/read-only live gates passed on 2026-08-27. The user still
   needs to approve the manual Audio, Dock and Bluetooth visual/interaction checkpoint.
3. **Network/Wi-Fi native slice — explicitly deferred.** Keep Wi-Fi diagnostic-only and do not
   select or implement a NetworkManager pattern until the Audio/Dock/Bluetooth checkpoint is
   approved.

The Wi-Fi diagnostic glyph remains a placeholder; Bluetooth is now backed by `BluetoothService`
and the Audio glyph by `AudioService`. No Network/Wi-Fi service stub should be added before its
slice is designed.

## Continuing reference-repository research

For each candidate repo, record license, revision, Quickshell version, architecture pattern,
runtime dependencies and the exact modules worth studying. Compare implementations before copying
code. The first research set should cover:

1. Hyprland Workspaces and System Tray.
2. Audio and reusable slider/OSD behavior.
3. Notifications and toast/center lifecycle.
4. Network/Bluetooth services only after the shared service pattern is agreed.

## Integration order

1. Replace one temporary bar widget using the selected reference pattern.
2. Add System Tray as a bounded bar module.
3. Establish animation and theme-input policy (static JSON or matugen) without coupling features.
4. Add notifications after the Audio/Dock/Bluetooth visual checkpoint, each as Service → View →
   live acceptance.
5. Revisit Settings only after several real modules expose stable preferences.

Spotlight and Input Method remain protected throughout. Major surfaces such as Window Switcher or
a new Settings Center require their own design and test checkpoint; they are not placeholders in
the skeleton.
