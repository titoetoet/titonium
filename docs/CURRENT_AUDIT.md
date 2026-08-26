# Current audit — skeleton baseline

The August 2026 contraction removed 121 superseded QML/JavaScript files plus obsolete layout,
theme, settings, migration and acceptance infrastructure. Git commit `62f8ba1` is the last complete
pre-contraction runtime reference; the later history remains available for selective archaeology.

## Kept because it is distinctive or foundational

- Spotlight Applications/Clipboard/System-mock flow and its keybindings.
- Fcitx input indicator backed by native SystemTray events.
- Dynamic multi-monitor `Variants` lifecycle for bar and overlay host.
- One lazy transient-surface coordinator.
- Application, Clipboard and Hyprland service boundaries.
- Small Neutral Utility token and shared-control layer.
- Namespaced Vietnamese/English i18n fallback.

## Temporary baseline

Workspaces and Clock remain visible so the bar is useful while reference repositories are reviewed.
They are intentionally small and replaceable.

## Removed from runtime

Settings Center, Arch Menu/session confirmation, Active Window, Calendar/Lunar, Frame, Design
Gallery, recursive JSON layout, widget registry, theme catalog/hybrid glass and their god-object
configuration path. None may be restored wholesale. A future capability returns only through a
new contract, explicit research decision and focused acceptance test.
