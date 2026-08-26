# Titonium Native Audio Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the End-island Audio diagnostic with a native PipeWire service, a lazy Master/Microphone/Application-stream mixer popup and a focused-monitor volume OSD.

**Architecture:** One `AudioService` singleton is the only owner of Quickshell PipeWire objects and exposes normalized state plus bounded mutation methods. The popup reuses `SurfaceManager`; the OSD has a separate no-focus per-screen host and a one-shot coordinator so input surfaces and presentation-only feedback keep independent lifecycles.

**Tech Stack:** Quickshell 0.3.1, QML/QtQuick, `Quickshell.Services.Pipewire`, `PwObjectTracker`, QtQuick Controls Slider, repository-local JavaScript domain helpers, Node fixtures, Python architecture gates and Bash foreground IPC acceptance.

**Spec:** `docs/superpowers/specs/2026-08-26-audio-native-slice-design.md`

## Global Constraints

- Work directly in `/home/cole/Projects/titonium`; do not create a second shell or compatibility tree.
- Preserve protected Spotlight Applications/Clipboard/System, Input Method and their current keybindings.
- Runtime implementation is QML, QtQuick and repository-local JavaScript only.
- Only `Titonium/Services/Audio` may import `Quickshell.Services.Pipewire`.
- UI may not own `Process`, `FileView`, persistence, raw commands or raw `PwNode` mutation.
- Do not invoke `wpctl`, `pactl`, Go, Python, shell helpers or external audio daemons.
- Do not copy DMS source, imports, theme, global settings or Go/CLI backend.
- Do not add MPRIS, sound effects, device/port selection, Bluetooth or Network implementation.
- Do not add polling timers, shaders, `MultiEffect`, infinite animation or an always-active heavy Loader.
- Automated tests must not change real volume, mute state, default devices or application streams.
- Do not edit either Hyprland configuration file.
- User-facing strings use namespaced `I18n.tr()` keys and EN/VI catalogs retain identical key sets.
- Use `apply_patch` for source edits and preserve unrelated user changes.

## Target file map

```text
Titonium/Services/Audio/qmldir
Titonium/Services/Audio/AudioRules.js              # pure clamp/icon/filter/label/OSD policy
Titonium/Services/Audio/AudioService.qml           # sole PipeWire owner and normalized state
Titonium/Overlays/Audio/qmldir
Titonium/Overlays/Audio/AudioPopupCoordinator.qml  # SurfaceManager descriptor/lifecycle only
Titonium/Overlays/Audio/AudioPopupSurface.qml      # outside click, Escape and anchored panel
Titonium/Overlays/Audio/AudioControlRow.qml        # Output/Microphone control
Titonium/Overlays/Audio/AudioStreamRow.qml         # application-stream control
Titonium/Overlays/Audio/AudioSlider.qml            # drag-local slider binding
Titonium/Osd/Audio/qmldir
Titonium/Osd/Audio/AudioOsdCoordinator.qml         # event coalescing and 1.2s lifetime
Titonium/Osd/Audio/AudioOsdHost.qml                # dynamic per-screen no-focus layer surface
Titonium/Osd/Audio/AudioOsd.qml                    # horizontal bottom-center pill
Titonium/Bar/islands/ConnectivityPill.qml          # real Audio button; Wi-Fi/BT stay diagnostic
Titonium/Bar/islands/EndIsland.qml                 # passes screen to connectivity pill
Titonium/App.qml                                   # composition and read-only acceptance IPC
config/defaults/settings.json                      # settings v6 Audio preference
config/schemas/settings.schema.json                # settings v6 schema
config/i18n/{en,vi}.json                           # Audio labels/state/feedback
scripts/check_audio_rules.js                       # pure domain fixtures
scripts/check_audio.py                             # ownership/lifecycle/forbidden-dependency gate
scripts/audio_acceptance.sh                        # read-only live acceptance
scripts/check_preferences.js                       # v5 projection and v6 preference fixtures
scripts/validate_config.py                         # settings v6 validator
scripts/check.sh                                   # registers static/domain checks
docs/{ARCHITECTURE,ROADMAP,TESTING}.md             # handoff and next slice
```

---

### Task 1: Define pure Audio policy contracts

**Files:**
- Create: `Titonium/Services/Audio/AudioRules.js`
- Create: `scripts/check_audio_rules.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Produces: `maximumOutput(allowAmplification): real`; `clampOutput(value, allowAmplification): real|null`; `clampUnit(value): real|null`; `adjustOutput(value, delta, allowAmplification): real|null`; `volumeIcon(available, muted, volume): string`; `isPlaybackStream(node): bool`; `streamName(node, fallback): string`; `streamIcon(node): string`; `normalizedStreams(nodes, fallback): array`; `presentationEvent(previous, current): object`.
- Consumes: no QML/runtime object; every helper accepts plain objects so fixtures can use fakes.

- [ ] **Step 1: Write the failing Node fixture**

Use the existing `vm` loader pattern and assert these exact domain rules:

```javascript
assert.equal(rules.maximumOutput(false), 1.0);
assert.equal(rules.maximumOutput(true), 1.5);
assert.equal(rules.clampOutput(1.3, false), 1.0);
assert.equal(rules.clampOutput(1.3, true), 1.3);
assert.equal(rules.clampOutput(Number.NaN, true), null);
assert.equal(rules.clampUnit(-0.5), 0.0);
assert.equal(rules.clampUnit(1.2), 1.0);
assert.equal(rules.adjustOutput(0.98, 0.05, false), 1.0);
assert.equal(rules.adjustOutput(1.0, 0.05, true), 1.05);

assert.equal(rules.volumeIcon(false, false, 0.5), "volume_off");
assert.equal(rules.volumeIcon(true, true, 0.5), "volume_off");
assert.equal(rules.volumeIcon(true, false, 0.0), "volume_mute");
assert.equal(rules.volumeIcon(true, false, 0.2), "volume_down");
assert.equal(rules.volumeIcon(true, false, 0.6), "volume_up");

const playback = { id: 7, audio: { volume: 0.4, muted: false },
    isStream: true, isSink: false,
    properties: { "application.name": "Firefox", "application.icon-name": "firefox" } };
assert.equal(rules.isPlaybackStream(playback), true);
assert.equal(rules.isPlaybackStream({ audio: {}, isStream: true, isSink: true }), false);
assert.equal(rules.streamName(playback, "Audio stream"), "Firefox");
assert.equal(rules.streamIcon(playback), "firefox");

assert.equal(rules.presentationEvent(null,
    { key: "sink:1", available: true, volume: 0.5, muted: false }).emit, false);
assert.equal(rules.presentationEvent(
    { key: "sink:1", available: true, volume: 0.5, muted: false },
    { key: "sink:1", available: true, volume: 0.6, muted: false }).emit, true);
assert.equal(rules.presentationEvent(
    { key: "sink:1", available: true, volume: 0.6, muted: false },
    { key: "sink:2", available: true, volume: 0.6, muted: false }).emit, false);
assert.equal(rules.presentationEvent(
    { key: "sink:1", available: true, volume: 0.6, muted: false },
    { key: "", available: false, volume: 0, muted: false }).emit, false);
```

Also require `normalizedStreams()` to exclude hardware and recording streams, sort names
case-insensitively then IDs, and return new descriptor objects containing only
`id,name,icon,volume,muted,available`.

- [ ] **Step 2: Run the fixture and verify RED**

Run: `node scripts/check_audio_rules.js`

Expected: FAIL because `AudioRules.js` does not exist.

- [ ] **Step 3: Implement the minimum policy library**

Use finite-number checks before clamping. `presentationEvent()` returns
`{ emit: bool, next: normalizedState }`; it emits only when the same available sink key changes
volume or mute after a baseline exists. `normalizedStreams()` never retains a node reference.

- [ ] **Step 4: Register and verify GREEN**

Add `node "$project_root/scripts/check_audio_rules.js"` after the Center action fixture in
`scripts/check.sh`.

Run:

```bash
node scripts/check_audio_rules.js
./scripts/check.sh
```

Expected: Audio fixtures and the complete static gate pass.

- [ ] **Step 5: Commit the pure boundary**

```bash
git add Titonium/Services/Audio/AudioRules.js scripts/check_audio_rules.js scripts/check.sh
git commit -m "test: define native audio policies"
```

---

### Task 2: Add the native PipeWire service and read-only acceptance seam

**Files:**
- Create: `Titonium/Services/Audio/qmldir`
- Create: `Titonium/Services/Audio/AudioService.qml`
- Create: `scripts/check_audio.py`
- Create: `scripts/audio_acceptance.sh`
- Modify: `Titonium/App.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Modify: `scripts/check_services.py`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: all `AudioRules` functions from Task 1; `Preferences.settings.modules.audio` when present.
- Produces: singleton properties `ready`, `outputAvailable`, `outputName`, `outputIcon`,
  `outputVolume`, `outputMuted`, `inputAvailable`, `inputName`, `inputVolume`, `inputMuted`,
  `playbackStreams`, `allowAmplification`, `maximumOutputVolume`; methods `setOutputVolume`,
  `adjustOutputVolume`, `toggleOutputMute`, `setInputVolume`, `toggleInputMute`,
  `setStreamVolume`, `toggleStreamMute`; signal
  `outputPresentationChanged(real volume, bool muted)`; read-only IPC `audio.state()`.

- [ ] **Step 1: Extend service/Audio gates and verify RED**

Create `scripts/check_audio.py` requiring `AudioService.qml`, `AudioRules.js` and `qmldir`. Require
the following source contracts:

```python
required_fragments = (
    "import Quickshell.Services.Pipewire",
    "PwObjectTracker {",
    "objects: Pipewire.nodes.values.filter",
    "readonly property bool outputAvailable",
    "readonly property var playbackStreams",
    "signal outputPresentationChanged(real volume, bool muted)",
    "function setOutputVolume(value: real): bool",
    "function adjustOutputVolume(delta: real): bool",
    "function toggleOutputMute(): bool",
    "function setInputVolume(value: real): bool",
    "function toggleInputMute(): bool",
    "function setStreamVolume(nodeId: int, value: real): bool",
    "function toggleStreamMute(nodeId: int): bool",
)
```

Scan all QML outside `Titonium/Services/Audio` and fail on
`import Quickshell.Services.Pipewire`. Scan the service and fail on `Process`, `FileView`,
`execDetached`, `wpctl`, `pactl`, `Timer {` or service imports for MPRIS/Bluetooth/Network.

Run: `python3 scripts/check_audio.py`

Expected: FAIL because the QML module does not exist.

- [ ] **Step 2: Implement normalized reactive service state**

Declare `module qs.Titonium.Services.Audio`, with `singleton AudioService 1.0 AudioService.qml`.
The service owns:

```qml
readonly property var outputNode: Pipewire.defaultAudioSink
readonly property var inputNode: Pipewire.defaultAudioSource
readonly property bool ready: Pipewire.ready
readonly property bool allowAmplification:
    Preferences.settings.modules?.audio?.allowAmplification === true
readonly property real maximumOutputVolume:
    AudioRules.maximumOutput(root.allowAmplification)

property PwObjectTracker tracker: PwObjectTracker {
    objects: Pipewire.nodes.values.filter(node => node?.audio !== null)
}
```

Expose normalized output/input values with unavailable fallbacks. Derive `playbackStreams` with
`AudioRules.normalizedStreams(Pipewire.nodes.values, I18n.tr("audio.stream.fallback"))`. Setter
methods re-find the current node by numeric ID immediately before mutation and return false for a
missing/unready/audio-less node. Never cache a mutable raw node in a descriptor.

Use `Connections` to `outputNode?.audio` plus default-node/readiness changes. Keep one plain
`previousPresentation` object. Feed every observation through `AudioRules.presentationEvent()`;
store `.next` first and emit only when `.emit` is true. Default-node changes reset the baseline.

- [ ] **Step 3: Add read-only IPC and translations**

Import `qs.Titonium.Services.Audio` in `App.qml`. Add only:

```qml
IpcHandler {
    target: "audio"
    function state(): string {
        return "ready=" + AudioService.ready
            + ";output=" + AudioService.outputAvailable
            + ";volume=" + Math.round(AudioService.outputVolume * 100)
            + ";muted=" + AudioService.outputMuted
            + ";input=" + AudioService.inputAvailable
            + ";streams=" + AudioService.playbackStreams.length;
    }
}
```

Do not expose any setter/mute/adjust IPC. Add EN/VI keys for the stream fallback, unavailable
state, output, microphone, applications, muted and percentage accessibility text.

- [ ] **Step 4: Add a read-only foreground service acceptance**

Create `scripts/audio_acceptance.sh` using the foreground PID pattern from
`center_notch_acceptance.sh`. It launches `qs -n -p "$project_root" --no-color`, waits for
`app status`, calls only `audio state`, requires this exact shape and rejects runtime error patterns:

```text
^ready=(true|false);output=(true|false);volume=[0-9]+;muted=(true|false);input=(true|false);streams=[0-9]+$
```

Snapshot Git status before launch and require it unchanged before cleanup. Do not call any Audio
mutation method.

- [ ] **Step 5: Register gates and verify service GREEN**

Add Audio module files to `check_services.py`, run `python3 scripts/check_audio.py` from
`scripts/check.sh`, and add `bash -n "$project_root/scripts/audio_acceptance.sh"`. Run:

```bash
python3 scripts/check_audio.py
./scripts/check.sh
./scripts/smoke.sh
./scripts/audio_acceptance.sh
```

Expected: static and smoke pass; IPC matches
`^ready=(true|false);output=(true|false);volume=[0-9]+;muted=(true|false);input=(true|false);streams=[0-9]+$`.
The commands do not mutate audio.

- [ ] **Step 6: Commit the service slice**

```bash
git add Titonium/Services/Audio Titonium/App.qml config/i18n scripts/check_audio.py \
  scripts/audio_acceptance.sh scripts/check_services.py scripts/check.sh
git commit -m "feat: add native pipewire audio service"
```

---

### Task 3: Add the lazy Audio mixer popup and real End-island button

**Files:**
- Create: `Titonium/Overlays/Audio/qmldir`
- Create: `Titonium/Overlays/Audio/AudioPopupCoordinator.qml`
- Create: `Titonium/Overlays/Audio/AudioPopupSurface.qml`
- Create: `Titonium/Overlays/Audio/AudioControlRow.qml`
- Create: `Titonium/Overlays/Audio/AudioStreamRow.qml`
- Create: `Titonium/Overlays/Audio/AudioSlider.qml`
- Modify: `Titonium/Bar/islands/ConnectivityPill.qml`
- Modify: `Titonium/Bar/islands/EndIsland.qml`
- Modify: `Titonium/App.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Modify: `scripts/check_audio.py`
- Modify: `scripts/audio_acceptance.sh`

**Interfaces:**
- Consumes: `AudioService` normalized state/methods; `SurfaceManager`; screen passed from `Bar`.
- Produces: `AudioPopupCoordinator.open(screen): bool`, `toggle(screen): bool`, `close(): bool`, `active: bool`; read-only IPC `audio.popup()`, `closePopup()`, `popupState()`.

- [ ] **Step 1: Extend popup contracts and verify RED**

Require all six `Overlays/Audio` files, a singleton coordinator, a surface containing outside-click
and Escape close, and these view calls only:

```text
AudioService.setOutputVolume
AudioService.toggleOutputMute
AudioService.setInputVolume
AudioService.toggleInputMute
AudioService.setStreamVolume
AudioService.toggleStreamMute
```

Reject `Quickshell.Services.Pipewire`, `.audio.volume =`, `.audio.muted =`, Process, FileView,
commands and service imports other than `qs.Titonium.Services.Audio` in the Audio overlay.

Run: `python3 scripts/check_audio.py`

Expected: FAIL on the missing popup module.

- [ ] **Step 2: Implement drag-local slider and control rows**

`AudioSlider` wraps `QtQuick.Controls.Slider` and exposes:

```qml
property real serviceValue: 0
property real maximumValue: 1
signal userValueChanged(real value)
```

On completion and `serviceValueChanged`, copy service state to the control only while not pressed.
On `moved`, emit the local value. When pressing ends, resync to the latest service value. It owns
no service import.

`AudioControlRow.kind` is exactly `output` or `input`; it selects the corresponding normalized
properties/methods. `AudioStreamRow` requires one normalized descriptor and sends its ID back to
the service. Labels elide on one line; controls are focusable and have translated accessible names.

- [ ] **Step 3: Implement popup lifecycle and layout**

`AudioPopupCoordinator` is a singleton that opens owner `audio:<screen.name>` through
`SurfaceManager` with source `AudioPopupSurface.qml`, exclusive keyboard focus and
`closeOnMonitorChange: true`. It derives `active` from the current SurfaceManager owner; it owns no
Loader, Timer or service state.

`AudioPopupSurface` fills the overlay for outside-click capture and places a solid 380px panel at
`top: 40 + Metrics.barSpacing`, `right: Metrics.barPadding`, with maximum height 520. Output and
Microphone remain above a separator. Only the Applications `ListView` scrolls. Empty and
unavailable states are translated. Escape and outside click close the exact Audio owner.

- [ ] **Step 4: Replace only the Audio diagnostic**

Pass `screen` into `ConnectivityPill`. Keep Wi-Fi and Bluetooth muted diagnostic icons. Add one
48-or-smaller quiet Audio button whose icon and accessible name read `AudioService`; click toggles
the popup and `WheelHandler` calls `adjustOutputVolume(±0.05)`. `showDiagnostics` hides only the
Wi-Fi/Bluetooth diagnostics; the real Audio button remains present. Recalculate
`fullImplicitWidth` independently of optional visibility to avoid the previous width binding loop.

In `App.qml`, add a `Connections` handler for `SurfaceManager.opened` that closes the Center Notch
for any nonempty transient surface. Extend the Audio IPC with safe popup open/close/state methods;
do not expose volume mutation.

- [ ] **Step 5: Verify popup behavior**

Extend `audio_acceptance.sh` to call `audio popup`, require `open:<screen>`, verify
`audio popupState` has the same owner, then call `audio closePopup` and require `closed`. Keep the
script read-only with respect to PipeWire.

Run:

```bash
python3 scripts/check_audio.py
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
./scripts/audio_acceptance.sh
```

Expected: all gates pass; popup state changes open → closed; protected acceptance remains green;
no automated command changes volume or mute.

- [ ] **Step 6: Commit the popup slice**

```bash
git add Titonium/Overlays/Audio Titonium/Bar/islands Titonium/App.qml config/i18n \
  scripts/check_audio.py scripts/audio_acceptance.sh
git commit -m "feat: add native audio mixer popup"
```

---

### Task 4: Add the focused-monitor output-volume OSD

**Files:**
- Create: `Titonium/Osd/Audio/qmldir`
- Create: `Titonium/Osd/Audio/AudioOsdCoordinator.qml`
- Create: `Titonium/Osd/Audio/AudioOsdHost.qml`
- Create: `Titonium/Osd/Audio/AudioOsd.qml`
- Modify: `Titonium/App.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Modify: `scripts/check_audio.py`
- Modify: `scripts/audio_acceptance.sh`

**Interfaces:**
- Consumes: `AudioService.outputPresentationChanged(volume, muted)` and `HyprlandService.focusedMonitorName`.
- Produces: `AudioOsdCoordinator.show(screenName, volume, muted): bool`, `hide(): bool`, `active`, `ownerScreenName`, `volume`, `muted`; per-screen lazy no-focus OSD host; read-only `audio.osdState()`.

- [ ] **Step 1: Extend OSD contracts and verify RED**

Require all four `Osd/Audio` files. Require `Variants { model: Quickshell.screens }`,
`Loader.active` tied to screen ownership, `WlrKeyboardFocus.None`, `exclusiveZone: 0`, bottom anchor,
and a coordinator timer with `interval: 1200`, `repeat: false`. Reject repeat timers, input handlers,
SurfaceManager imports, PipeWire imports and heavy content outside the Loader.

Run: `python3 scripts/check_audio.py`

Expected: FAIL on missing OSD files.

- [ ] **Step 2: Implement the coordinator and event coalescing**

The coordinator listens to `AudioService.outputPresentationChanged`. It resolves the current
focused monitor name, updates one payload, sets active true and calls `hideTimer.restart()`.
`show()` rejects an empty screen name. `hide()` clears ownership and resets the payload. Repeated
events overwrite the existing payload instead of creating a second OSD.

- [ ] **Step 3: Implement per-screen no-focus host and pill**

`AudioOsdHost` uses `Variants(Quickshell.screens)`. Each delegate is a transparent overlay-layer
`PanelWindow`, bottom anchored and horizontally unanchored so its fixed width is centered. It is
visible only for its owner screen, has `exclusiveZone: 0`, `WlrKeyboardFocus.None` and an empty
input region. Its Loader is active only while visible.

`AudioOsd` is a solid horizontal pill with icon, bounded progress track and translated Muted or
percentage text. It has no pointer handlers. Its enter/exit durations use Motion tokens and become
zero with reduced motion; no animation loops.

- [ ] **Step 4: Compose host and add read-only state**

Instantiate `AudioOsdHost {}` once in `App.qml`. Extend the existing `audio` IPC handler with:

```qml
function osdState(): string {
    return AudioOsdCoordinator.active
        ? "active:" + AudioOsdCoordinator.ownerScreenName : "idle";
}
```

Do not expose `show()` through IPC because that would bypass the real service event policy.

- [ ] **Step 5: Verify OSD idle lifecycle**

Extend `audio_acceptance.sh` to require `audio osdState` equals `idle` before and after popup
lifecycle checks. It must not expose or call an OSD-show IPC.

Run:

```bash
python3 scripts/check_audio.py
./scripts/check.sh
./scripts/smoke.sh
./scripts/audio_acceptance.sh
```

Expected: `idle`; no OSD Loader is active at rest; no runtime error appears. Manually change output
volume once with an existing multimedia key and verify one bottom-center OSD on the focused screen,
then verify it unloads after 1.2 seconds.

- [ ] **Step 6: Commit the OSD slice**

```bash
git add Titonium/Osd/Audio Titonium/App.qml config/i18n scripts/check_audio.py \
  scripts/audio_acceptance.sh
git commit -m "feat: add focused monitor audio osd"
```

---

### Task 5: Advance settings projection to v6 amplification policy

**Files:**
- Modify: `config/defaults/settings.json`
- Modify: `config/schemas/settings.schema.json`
- Modify: `Titonium/Core/Runtime/PreferencesValidator.js`
- Modify: `Titonium/Core/Runtime/Preferences.qml`
- Modify: `scripts/check_preferences.js`
- Modify: `scripts/validate_config.py`
- Modify: `scripts/check_audio.py`

**Interfaces:**
- Consumes: the optional legacy/current runtime settings document.
- Produces: `Preferences.allowAudioAmplification: bool`; projected `modules.audio.allowAmplification`; settings schema ID/version 6.

- [ ] **Step 1: Extend preference fixtures and verify RED**

Change default assertions to require schema v6 and false amplification. Keep the existing v5 legacy
fixture with `audio: { maxVolume: 150 }` and assert that retired shape does not enable boost:

```javascript
assert(projectedLegacy.modules.audio.allowAmplification === false,
    "legacy maxVolume does not enable amplification");
```

Add a v6 fixture:

```javascript
const currentRuntime = {
    schemaVersion: 6,
    locale: "vi",
    appearance: { mode: "dark" },
    accessibility: { reducedMotion: false },
    applications: { hiddenIds: [] },
    modules: {
        spotlight: { pageTransition: "slide-fade", transitionDuration: 220 },
        clock: { use24Hour: true },
        audio: { allowAmplification: true }
    }
};
assert(context.project(currentRuntime, defaults).modules.audio.allowAmplification === true,
    "v6 amplification preference is preserved");
```

Run: `node scripts/check_preferences.js`

Expected: FAIL because the projector currently removes Audio settings.

- [ ] **Step 2: Update shipped settings, schema and Python validator**

Set `$schema` to `titonium.settings/v6`, `schemaVersion` to `6`, require modules
`spotlight`, `clock`, `audio`, and require Audio to contain only boolean `allowAmplification`.
Update `validate_config.py` constants and exact-shape checks accordingly.

- [ ] **Step 3: Update tolerant runtime projection**

Project:

```javascript
audio: {
    allowAmplification: source.schemaVersion === 6
        && source.modules?.audio?.allowAmplification === true
}
```

This deliberately ignores the legacy `maxVolume` shape. Expose
`Preferences.allowAudioAmplification` and update `AudioService` to consume that property rather
than reading the settings object directly.

- [ ] **Step 4: Verify migration and runtime isolation**

Run:

```bash
node scripts/check_preferences.js
python3 scripts/validate_config.py
python3 scripts/check_audio.py
./scripts/check.sh
./scripts/smoke.sh
git status --short
```

Expected: all gates pass; smoke does not write the repository; default cap is 100%.

- [ ] **Step 5: Commit settings v6**

```bash
git add config/defaults/settings.json config/schemas/settings.schema.json \
  Titonium/Core/Runtime/PreferencesValidator.js Titonium/Core/Runtime/Preferences.qml \
  Titonium/Services/Audio/AudioService.qml scripts/check_preferences.js \
  scripts/validate_config.py scripts/check_audio.py
git commit -m "feat: add audio amplification preference"
```

---

### Task 6: Add read-only live acceptance and handoff documentation

**Files:**
- Modify: `scripts/audio_acceptance.sh`
- Modify: `scripts/check.sh`
- Modify: `scripts/check_audio.py`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: `audio.state()`, `popup()`, `closePopup()`, `popupState()`, `osdState()` and existing Spotlight/Center Notch IPC.
- Produces: repeatable foreground Audio acceptance with zero real audio mutation and the visual checkpoint before Bluetooth.

- [ ] **Step 1: Harden the foreground acceptance script**

Follow `center_notch_acceptance.sh`: snapshot Git status and both Hyprland hashes, launch one
foreground `qs -n -p "$project_root" --no-color`, wait for `app status`, and clean up through a
trap. Exercise only this safe sequence:

```text
audio state               -> valid read-only state format
audio osdState            -> idle
audio popup               -> open:<focused-screen>
audio popupState          -> open:<same-screen>
centerNotch open overview -> Audio popup closed
centerNotch close
audio popup
spotlight toggle          -> Audio popup closed
spotlight close
audio closePopup          -> closed
```

Reject logs matching:

```text
ERROR|TypeError|Illegal method name|Type .* unavailable|duplicate id|missing method
```

The script must not call or expose volume, mute, adjust, OSD-show or device-selection IPC.

- [ ] **Step 2: Extend static performance and mutation gates**

Make `check_audio.py` reject:

- `Timer { repeat: true }` anywhere in Audio;
- any OSD Loader not tied to `AudioOsdCoordinator.active` and owner screen;
- any popup Loader outside the existing `OverlayHost` lifecycle;
- raw `.audio.volume =` or `.audio.muted =` outside `Services/Audio`;
- `Process`, `FileView`, `execDetached`, `wpctl`, `pactl`, MPRIS, Bluetooth or Network imports;
- Audio IPC methods whose names match `set|adjust|toggleMute|showOsd|device`.

Temporarily add a test fixture under `Titonium/Overlays/Audio` containing
`Process { command: ["wpctl"] }`, run the gate and verify RED; delete the fixture with
`apply_patch`, then verify the real tree GREEN.

- [ ] **Step 3: Register and run the full acceptance set**

Keep `bash -n "$project_root/scripts/audio_acceptance.sh"` in `scripts/check.sh`. Keep live Audio
acceptance explicit. Run:

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
./scripts/center_notch_acceptance.sh
./scripts/audio_acceptance.sh
hyprctl configerrors
```

Expected: all gates pass, Hyprland reports no configuration error, Git and both Hyprland hashes are
unchanged, and runtime logs contain `Configuration Loaded` without a rejection pattern.

- [ ] **Step 4: Perform the two-monitor manual checklist**

On DP-1 scale 1.5 and DP-3 scale 1.0 verify:

- Audio icon reflects current output and remains visible when Wi-Fi/BT diagnostics collapse;
- click and outside-click/Escape popup lifecycle;
- popup right-edge anchoring and bounded height;
- Output/Microphone controls and local drag behavior;
- playback applications appear/disappear without closing the popup;
- multimedia-key/external volume changes update Bar and produce one focused-screen OSD;
- OSD is bottom-centered, click-through, coalesces changes and unloads after 1.2 seconds;
- startup and output hotplug do not flash a false OSD;
- default cap is 100%; a prepared v6 runtime fixture allows 150%;
- Spotlight, Input Method and Center Notch remain correct.

Restore the original user audio level/mute and runtime settings after manual testing. Stop for user
review; do not begin Bluetooth automatically.

- [ ] **Step 5: Update architecture, testing and roadmap**

Document the sole PipeWire owner, normalized view contract, tracker requirement, popup/OSD split,
initialization guard, read-only acceptance and manual mutation policy. Mark Audio native slice as
complete only after visual approval. Set the next roadmap item to “Bluetooth native slice —
awaiting design”, followed by Network; do not describe MPRIS/device selection as implemented.

- [ ] **Step 6: Commit the accepted handoff**

```bash
git add scripts/audio_acceptance.sh scripts/check.sh scripts/check_audio.py \
  docs/ARCHITECTURE.md docs/ROADMAP.md docs/TESTING.md
git commit -m "test: accept native audio slice"
```

## Final verification

Run after the last commit:

```bash
git status --short
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
./scripts/center_notch_acceptance.sh
./scripts/audio_acceptance.sh
hyprctl configerrors
git log --oneline -6
```

Expected:

- Git status is empty before and after runtime tests.
- All five test/acceptance commands pass.
- `hyprctl configerrors` is empty.
- Six commits correspond to the six reviewable tasks.
- No Go, Python runtime, shell audio helper, external daemon, MPRIS, device switching, Bluetooth or
  Network implementation exists.
