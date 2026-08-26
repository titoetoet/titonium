# Titonium Native Audio Slice Design

**Date:** 2026-08-26  
**Status:** Approved design  
**Scope:** PipeWire volume service, Audio popup mixer and output-volume OSD

## Context

Titonium now has a QML-native multi-monitor skeleton, protected Spotlight and Input Method flows,
three independent Bar islands and a lazy Center Notch. The End island still shows diagnostic
Wi-Fi, Bluetooth and Audio glyphs. This slice replaces only the Audio diagnostic with real native
state. Bluetooth and Network remain separate future slices.

The implementation stays QML-first. It must not invoke `wpctl`, `pactl`, a Go/Python helper, a
shell script or an external daemon. It must not import DMS services, global state or theme code.

## User decisions

- The first popup contains Master Output, Microphone and active playback application streams.
- Device selection, port selection and MPRIS/media are deferred.
- The OSD is a horizontal pill centered near the bottom of the focused screen.
- Output volume/mute changes from Titonium or an external actor show the OSD after initialization.
- Output volume is capped at 100% by default. An `allowAmplification` preference raises the cap to
  150%.
- Amplification is configuration-only in this slice; no new Settings editor is introduced.

## Goals

1. Own PipeWire integration in one service singleton and expose normalized reactive state.
2. Replace the End-island Audio diagnostic with an accessible live button.
3. Provide a lazy transient mixer popup with Output, Microphone and playback stream controls.
4. Provide a lazy, click-through, no-focus output-volume OSD on the focused monitor.
5. Preserve Spotlight, Input Method, Center Notch and dynamic screen lifecycle behavior.
6. Remain idle without polling, render loops or permanently loaded heavy surfaces.

## Non-goals

- Selecting default devices or ports.
- MPRIS, media metadata, visualizers or sound effects.
- Network, Bluetooth or notification implementation.
- A complete Settings Center or runtime settings writer.
- Recording-stream controls, per-channel balance or audio routing.
- Copying DMS source or retaining its Go/CLI/service dependencies.

## Sources and provenance

### Quickshell 0.3.1 documentation

- `Pipewire`: default sink/source, readiness and node registry.
- `PwNode`: node identity, stream/sink classification and display metadata.
- `PwNodeAudio`: reactive volume/mute state and mutation.
- `PwObjectTracker`: required binding for full node/audio properties.

References:

- <https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pipewire/Pipewire/>
- <https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pipewire/PwNode/>
- <https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pipewire/PwNodeAudio/>

### DankMaterialShell

- Repository: <https://github.com/AvengeMedia/DankMaterialShell>
- License: MIT
- Inspected revision: `ea0b158eb8c7d368ae7083218dbfc792faf019b2`
- Inspected files:
  - `quickshell/Services/AudioService.qml`
  - `quickshell/Modules/ControlCenter/Widgets/AudioSliderRow.qml`
  - `quickshell/Modules/ControlCenter/Widgets/InputAudioSliderRow.qml`
  - `quickshell/Modules/OSD/VolumeOSD.qml`
  - `quickshell/Common/OSDManager.qml`

Useful ideas are the Master/Input hierarchy, suppressing slider feedback while dragging, one OSD
per screen and separating service state from controls. Rejected parts include direct raw-node
mutation in views, Process/CLI fallbacks, sound players, device/port aliases, global settings state,
MPRIS coupling and the DMS theme/widget stack. No upstream source is copied into Titonium.

Ambxst remains a layout reference for the existing Bar/Center Notch. It is not used as the Audio
backend reference for this slice.

## Architecture

```text
Quickshell.Services.Pipewire
             │
             ▼
Services/Audio/AudioService
  ├── tracked default output adapter
  ├── tracked default input adapter
  ├── tracked playback-stream adapters
  ├── normalized public state
  └── bounded mutation methods
        │          │             │
        ▼          ▼             ▼
  End Audio     Audio popup   Audio OSD coordinator
    button      via existing   + per-screen lazy host
                SurfaceManager
```

Only `Titonium/Services/Audio` imports `Quickshell.Services.Pipewire`. Raw `PwNode` and
`PwNodeAudio` references remain private to the service and internal adapters. Views receive
normalized properties and identify streams by stable PipeWire node ID. Views request mutations
through service methods; they never assign `node.audio.volume` or `node.audio.muted`.

The existing `SurfaceManager` owns the Audio popup, so Spotlight and Audio cannot overlap. The App
composition boundary closes `CenterNotchCoordinator` before opening Audio. The OSD is not a
transient input surface and therefore has its own coordinator/host lifecycle.

## Service contract

`AudioService` exposes:

```text
ready: bool
outputAvailable: bool
outputName: string
outputIcon: string
outputVolume: real             # normalized 0.0–1.5
outputMuted: bool
inputAvailable: bool
inputName: string
inputVolume: real
inputMuted: bool
playbackStreams: list<object>  # normalized service-owned adapters
allowAmplification: bool
maximumOutputVolume: real      # 1.0 or 1.5
```

Each playback adapter exposes only:

```text
id: int
name: string
icon: string
volume: real
muted: bool
available: bool
```

Mutation methods:

```text
setOutputVolume(value): bool
adjustOutputVolume(delta): bool
toggleOutputMute(): bool
setInputVolume(value): bool
toggleInputMute(): bool
setStreamVolume(nodeId, value): bool
toggleStreamMute(nodeId): bool
```

Invalid, missing or stale nodes return `false`. Numeric input must be finite. Output is clamped to
`maximumOutputVolume`; input and application streams are clamped to `1.0`. Increasing a muted
control above zero does not implicitly unmute it in this slice, keeping mute state explicit.

## Node classification and labels

- Default Output is `Pipewire.defaultAudioSink`.
- Default Microphone is `Pipewire.defaultAudioSource`.
- Playback streams satisfy `node.audio != null && node.isStream && !node.isSink`.
- Recording streams and hardware nodes are excluded from Applications.
- Stream ordering is stable by case-insensitive display name, then numeric node ID.
- Stream name fallback: `application.name`, `media.name`, node description, node nickname, then
  translated “Audio stream”.
- Stream icon fallback: `application.icon-name`, then `audio-x-generic`.

A `PwObjectTracker` binds every node whose full metadata or audio values are read. Registry and
default-node changes rebuild only the affected adapter set. No timer polls the registry.

## Initialization and OSD event policy

`Pipewire.ready === false`, an absent default sink, or an unbound node produces unavailable state.
When a default sink appears, the service records its initial volume/mute as a baseline without
emitting an OSD event. When the default sink changes or briefly becomes `null`, the guard resets.

After the baseline, any real change to default-output volume or mute emits one normalized event:

```text
outputPresentationChanged(volume, muted)
```

Application-stream and microphone changes do not show the output OSD. Repeated output changes
update the current payload and restart one one-shot hide lifetime rather than stacking OSDs.

`AudioOsdCoordinator` captures the focused monitor when it receives the event. A lightweight
`Variants(Quickshell.screens)` host activates a Loader only for that owner screen. The OSD uses no
keyboard focus, no input mask and no exclusive zone. It hides after 1.2 seconds; reduced motion
sets transition duration to zero. Its one-shot lifetime timer is not polling.

## Bar and popup interaction

The Audio glyph in `ConnectivityPill` becomes a real icon button:

- click opens/closes the Audio popup;
- wheel adjusts output by 5 percentage points;
- icon represents unavailable, muted, low, medium or high volume;
- accessible text includes the output state and percentage;
- Wi-Fi and Bluetooth remain non-interactive diagnostics.

The popup is a solid Neutral Utility surface approximately 380 logical pixels wide, anchored
below the End island with the existing Bar padding/gap. Height is content-driven and capped near
520 logical pixels. It closes on outside click, Escape or focused-monitor change.

The fixed upper region contains Output and Microphone rows. Each row contains an icon/mute button,
one-line node label, percentage and slider. The lower Applications region scrolls independently
and contains one row per playback stream. Empty or unavailable states are translated and do not
close the popup.

While a slider is pressed, its display value is local. Service updates rebind it when the drag
ends, avoiding thumb jumps while remaining reactive to external changes. Node removal destroys
only its row.

## Settings v6

Shipped settings advance from v5 to v6:

```json
"modules": {
  "spotlight": { "pageTransition": "slide-fade", "transitionDuration": 220 },
  "clock": { "use24Hour": true },
  "audio": { "allowAmplification": false }
}
```

The protected projector accepts v5 runtime data and supplies the v6 Audio default without changing
locale, appearance, accessibility, hidden applications, Spotlight or Clock. It also validates a
v6 runtime override. This slice remains read-only with respect to settings files. A later Settings
slice may write the preference atomically outside the repository.

## Error handling

- Missing PipeWire/default nodes disable controls and show translated unavailable state.
- A transient `null` during device changes never writes through a stale reference or shows OSD.
- A disappearing application stream is removed reactively.
- Invalid volume values are ignored and logged through `Logger` without crashing the shell.
- Missing labels/icons use deterministic fallbacks.
- There is no `wpctl`, `pactl`, Process or shell fallback.

## Testing and acceptance

Pure domain fixtures cover:

- 100%/150% clamp policy and invalid numbers;
- 5% adjustment steps;
- volume icon thresholds;
- playback-stream filtering and stable ordering;
- name/icon fallbacks;
- initialization/default-node OSD guard.

Static gates require the Audio service and tracker contract, forbid PipeWire imports outside
`Services/Audio`, and reject `Process`, raw commands, polling timers, persistence and raw node
mutation in Audio views. `qmllint` must add no unallowlisted warnings.

Foreground acceptance is read-only with respect to real audio state. It verifies configuration
load, a valid Audio IPC state shape, popup open/close, mutual exclusion with Spotlight/Center
Notch, an idle OSD Loader and clean runtime logs. Automated tests never change the user's real
volume or mute state.

Manual acceptance on DP-1 scale 1.5 and DP-3 scale 1.0 covers:

- live icon/percentage changes from multimedia keys;
- wheel, mute and every slider;
- application stream appearance/removal;
- OSD placement, coalescing and initialization suppression;
- popup anchoring, outside-click/Escape and monitor changes;
- 100% default cap and a separately prepared 150% runtime preference fixture;
- no regressions in Spotlight, Input Method or Center Notch.

## Delivery checkpoints

1. Native service, adapters, pure policies and read-only Bar state.
2. Lazy Audio popup with Output, Microphone and Applications.
3. Focused-monitor OSD and external-change initialization guard.
4. Settings v6 projection, focused acceptance, documentation and visual handoff.

Implementation stops after this slice for user review. Bluetooth, Network and MPRIS do not begin
automatically.
