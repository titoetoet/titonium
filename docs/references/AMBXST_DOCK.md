# Ambxst Dock provenance

## Reference record

Titonium studied the Dock interaction and lifecycle patterns in [Axenide/Ambxst](https://github.com/Axenide/Ambxst) at immutable revision [`65b7940cc325a425ddc443281b709db9bb7f3c6b`](https://github.com/Axenide/Ambxst/tree/65b7940cc325a425ddc443281b709db9bb7f3c6b). The reference is licensed **AGPL-3.0**. This is a provenance record, not a runtime dependency.

The inspected modules were:

| Ambxst path | Pattern studied |
| --- | --- |
| [`modules/dock/Dock.qml`](https://github.com/Axenide/Ambxst/blob/65b7940cc325a425ddc443281b709db9bb7f3c6b/modules/dock/Dock.qml) | Screen-scoped panel ownership, hitbox masking and conditional edge reservation. |
| [`modules/dock/DockContent.qml`](https://github.com/Axenide/Ambxst/blob/65b7940cc325a425ddc443281b709db9bb7f3c6b/modules/dock/DockContent.qml) | Bottom-edge reveal, pinned/auto-hide visibility and bounded slide/fade behavior. |
| [`modules/dock/DockAppButton.qml`](https://github.com/Axenide/Ambxst/blob/65b7940cc325a425ddc443281b709db9bb7f3c6b/modules/dock/DockAppButton.qml) | Grouped running-application representation and per-application interaction. |

## Independent adaptation boundary

Titonium independently reimplemented only the interaction grammar that fits its own contracts:

- a bottom-centered, screen-owned Dock with a narrow reveal region;
- pinned versus auto-hide lifecycle and conditional exclusive-zone reservation;
- stable application grouping, bounded hover motion and keyboard/mouse actions.

No Ambxst source code was copied. Titonium does not import, vendor or depend on Ambxst's `axctl`, global state objects, shader or `MultiEffect` effects, unified panel, theme engine, shell root or service architecture. In particular, Ambxst's `axctl`/global/shader/unified-panel boundary is not part of Titonium's runtime or public interface.

The adapted behavior is implemented behind Titonium-owned boundaries:

- `Titonium/Dock/DockWindow.qml` owns the DP-1 layer, mask and reservation;
- `Titonium/Dock/DockSurface.qml` owns presentation and focus order;
- `Titonium/Services/Dock/DockService.qml` owns native Hyprland toplevels and normalized descriptors;
- `Titonium/Services/Dock/DockStore.qml` owns runtime pin persistence.

Titonium's solid Neutral Utility surface, `ScreenPolicy.screens` restriction, `SurfaceManager` transient contract, semantic theme tokens, i18n and read-only acceptance seams are native to Titonium and were not taken from the reference implementation.
