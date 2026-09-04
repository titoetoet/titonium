# Roadmap

The previous feature roadmap is retired. Work now advances by researched capability slices.

## Baseline — complete

- Dynamic multi-monitor bar and overlay lifecycle.
- Protected Spotlight Applications/Clipboard/System mock.
- Protected event-driven Input Method.
- Five-slot Workspaces and Active Window context in the Start island.
- Application, Clipboard and Hyprland service boundaries.
- Static Neutral Utility tokens, i18n and focused gates.
- Three independently positioned Bar islands with composed click-through regions.
- Lazy, screen-owned Center pill/notch with compact-to-banner/canvas geometry morphing.

## Current — native capability slices

1. **Audio native slice — awaiting visual approval.** Its PipeWire owner, normalized view contract,
   popup/OSD split and read-only acceptance are implemented; mark the slice complete only after
   the two-monitor visual and interaction checklist is approved.
2. **Native Dock + Bluetooth milestone — automated acceptance complete, visual approval pending.** The
   DP-1-only Dock, native `Quickshell.Bluetooth` service, state-aware connectivity button,
   lazy popup, pure rules and static/read-only live gates passed on 2026-08-27. The user still
   needs to approve the manual Audio, Dock and Bluetooth visual/interaction checkpoint.
3. **Network/Wi-Fi native slice — automated acceptance complete, visual approval pending.** Native
   networking ownership, normalized descriptors, secret boundary, compact Bar control and lazy
   popup are implemented without command helpers.
4. **Independent Notification Center — complete.** One native service, immutable bounded history,
   an always-present Bell, a lazy screen-owned history panel, standard actions, per-application
   policy, passive DP-1-only toasts and a critical FIFO Center route are covered by focused static
   and safe foreground acceptance.
5. **Settings Center V1 — implementation and isolated acceptance complete; visual approval
   pending.** Eight lazy pages now edit a single transactional settings v7 model with
   Preview/Apply/Cancel, legacy Dock projection and DP-1-only lifecycle. The remaining checkpoint
   is manual visual review plus persistence/rollback verification against backed-up live data.

Deferred notification work is persisted history and any future producer-specific policy. The retired
Center history view is not part of the independent Bell-owned panel.

## Continuing reference-repository research

For each candidate repo, record license, revision, Quickshell version, architecture pattern,
runtime dependencies and the exact modules worth studying. Compare implementations before copying
code. The first research set should cover:

1. Hyprland Workspaces and System Tray.
2. Audio and reusable slider/OSD behavior.
3. Notification Center and action lifecycle, building on the completed toast service.
4. Further Network/Bluetooth reliability and device-detail patterns.

## Integration order

1. Replace one temporary bar widget using the selected reference pattern.
2. Add System Tray as a bounded bar module.
3. Establish animation and theme-input policy (static JSON or matugen) without coupling features.
4. Add Notification Center/actions as a separate Service-contract extension → lazy View → live
   acceptance milestone; do not expand the ToastHost into a god surface.
5. Extend Settings only when another real module exposes a stable preference; keep mutation in the
   existing v7 transaction instead of adding per-page stores.

Spotlight and Input Method remain protected throughout. Major surfaces continue to require their
own design and test checkpoint; they are not placeholders in the skeleton.
