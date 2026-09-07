# Design styles implementation and validation

The Appearance picker exposes Glassmorphism, Material, Liquid Glass, Modern Flat and Neumorphism as separate paint implementations. Styles change surfaces, fields, buttons, toggles, sliders, menu rows and finite feedback motion. Connected and Classic remain independent layout choices; their paths, anchors, input masks and lifecycle ownership are preserved.

The five small cards use the same demo palette. The large preview uses the actual candidate palette and controls. Compact controls are deliberately disabled to make each card one selection target. Local preview layout buttons do not edit the configured bar layout. Try/Keep/Revert and Apply retain their existing transaction meanings. Advanced fields are disabled when a style does not use them, while stored overrides remain available for reset and roundtrip.

Existing `neutral`, `glass`, `soft` and `graphite` settings resolve through a frozen legacy catalog and do not migrate automatically to a new style. Fresh installations default to Modern Flat. Missing IDs in supported legacy schema migrations still resolve to Neutral. New styles do not bundle wallpaper pairs; a legacy Theme wallpaper policy requires choosing Keep or Custom before a new style can be applied.

## Glass capability

This implementation ships the readable local paint fallback. It does **not** enable compositor blur or refraction. The UI states this limitation. Background opacity stays at least .85; opaque styles ignore opacity overrides. No plugin was installed or loaded, and neither Hyprland configuration was edited or reloaded.

The installed Quickshell blur API loaded in a throwaway native fixture, but capture never returned a ready frame, so the moving-background, Connected-mask and refraction criteria remain unverified. HyprGlass additionally lacks the validated output/shape scope and rollback required here. See [backend research](research/2026-09-06-glass-backend.md). Liquid micro-motion uses bounded settling rather than a physical refraction simulation.

## Reproducible checks

- `./scripts/check.sh`: includes catalog/migration, style rules, real QML controls, candidate isolation, frozen popup paint, consumer contracts and layout matrix tests, alongside existing project checks and qmllint.
- `python3 scripts/check_style_layout_ui.py`: 40 software-rendered combinations, five styles × two modes × two layouts × scale 1/1.5. Verifies layout bounds and focus retention and writes captures under `/tmp/titonium-style-matrix`.
- `python3 scripts/check_style_performance.py`: optional ~76-second software fixture; no production polling. Measures 30-second hidden/visible idle, ten-second control interactions and 20 cycles of all five renderers.
- `./scripts/smoke.sh` and `./scripts/protected_acceptance.sh`: native shell startup and protected flow checks. Use a separate snapshot and temporary XDG data/state/cache for unattended acceptance.

The software performance run observed zero frame submissions during both idle windows, .067% one-core CPU when visible, and unchanged RSS/descriptor endpoints after 100 loads/unloads. Animations ran and settled. This compares a warmed hidden fixture with its visible scene, **not** the pre-change native shell. GPU/frame-time p95, native morph/scroll budget and native glass resource accounting are still unverified; offscreen submissions are not physical display FPS.

## Final results (2026-09-06)

- Full `check.sh`: PASS, including the existing qmllint allowlist; no new lint warnings.
- Native foreground smoke: PASS. Complete protected acceptance: PASS. `hyprctl configerrors`: empty.
- Native startup plus Appearance/Audio/Bluetooth/Network/Center/Spotlight open-close paths: all 20 style × mode × layout combinations completed. This is runtime interaction coverage, not captured native visual fidelity.
- Classic emitted `classicTransitionPending` binding-loop diagnostics. The identical three diagnostics reproduced on an archived pre-change snapshot (`4ab92b6`, Neutral/light/Classic); no new error pattern appeared. The synchronous completion/ownership cycle predates these styles. It was documented and left unchanged to preserve lifecycle scope.
- 40 software capture combinations: PASS bounds/focus checks. Renderer tests: 20/20; explicit candidate/legacy popup regressions: 4/4; Appearance UI: 10/10; coordinator: 20/20.
- Paint, consumer and integration reviews completed; all actionable findings were fixed and re-reviewed.

Work ran in a detached snapshot of the existing dirty project. Integration back to the original workspace uses per-file SHA-256 baseline checks and copies only feature changes, preserving unrelated and staged work. No automatic style selection or wallpaper change is part of integration.
