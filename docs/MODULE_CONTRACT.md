# Module contract

A module is a vertical capability slice, not a widget file copied into the bar.

```text
Titonium/Services/<Capability>/   system adapter + shared reactive model
Titonium/Bar/widgets/             compact bar view, when needed
Titonium/Overlays/<Capability>/   lazy heavy surface, when needed
scripts/check_<capability>.*      pure and architecture checks
config/i18n/{vi,en}.json          reachable user strings
```

Create only the directories the capability actually needs.

## Service interface

A service may import Quickshell integration modules, observe native signals, persist runtime data
outside Git and expose narrow intent methods. It must:

- be a `Singleton` when state is shared;
- prefer events over polling;
- expose stable semantic state rather than DBus/IPC payloads;
- contain platform failure and provide a safe unavailable state;
- have pure JavaScript helpers for transformations worth unit testing.

Native ownership is singular. Exactly one service file may import a capability's Quickshell native
module. Views consume immutable value descriptors and semantic methods; they never retain or return
PipeWire nodes, Bluetooth devices, Network objects, Hyprland toplevels or native notifications.

## View interface

A view receives explicit context such as `screen` and reads a service singleton. It may emit user
intent or call a narrow service method. It must not instantiate `Process`, `FileView`, execute raw
commands, persist state or reach into another feature's private QML objects.

Bar widgets remain cheap while visible. Heavy panels use `SurfaceManager` plus `OverlayHost`; their
`Loader.active` becomes false on close. Only one transient surface owns exclusive keyboard focus.
Independent non-focus surfaces such as OSD and notification toasts use their own DP-1-only host,
`ExclusionMode.Ignore`, `WlrKeyboardFocus.None` and an input mask limited to visible content.

## Adapting third-party code

Do not copy a repository's shell root, theme engine or god service. Extract the protocol or model
logic, rename it to Titonium vocabulary, remove unused behavior and wrap it in this contract.
Preserve copyright/license notices and add provenance to the capability's documentation or source
header. Tests must use fakes and must never launch a real app, execute a power action or overwrite
clipboard contents.
