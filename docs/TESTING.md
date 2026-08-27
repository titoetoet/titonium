# Testing

## Static gate

`./scripts/check.sh` validates shipped JSON/i18n, protected keybinds, source shape, service and bar
boundaries, preference projection, pure Application/Clipboard/Spotlight behavior and every QML file
with `qmllint`.

The Bar gate also validates true-center geometry, Center Notch navigation/transition fixtures,
immutable mock catalogs, locale-key parity and idle safety. `Timer`, shaders, `MultiEffect`, infinite
animation, executable mock boundaries and future connectivity-service imports are rejected.

The Audio contract gate additionally enforces the sole PipeWire owner, tracker-backed normalized
view contract, no repeating Audio timer, no raw audio mutation outside `Services/Audio`, no command
or future-service dependency and no mutating Audio IPC. Popup content must remain in the existing
`OverlayHost` lifecycle; the click-through OSD Loader must be tied to the active coordinator and
its owner screen.

The only allowlisted QML warning is Quickshell 0.3.x metadata marking documented `PanelWindow` as
uncreatable. New warnings are failures. UI code is rejected when it owns `Process`, `FileView` or
raw detached execution.

The screen-policy fixture requires Bar, transient overlays and Audio OSD hosts to share the
`DP-1`-only eligible-screen model. It verifies fail-closed disconnect behavior and reactive
eligibility when `DP-1` returns, preventing Titonium from reserving or drawing on `DP-3`.

## Native Dock + Bluetooth handoff (Task 8)

The implementation has static contracts and read-only acceptance seams. The controller completed
the automated live gates on 2026-08-27; the user's manual visual/interaction checkpoint remains
pending. The commands below are the repeatable handoff procedure.

Recorded automated evidence:

- `./scripts/check.sh`, `./scripts/smoke.sh`, `./scripts/dock_acceptance.sh`,
  `./scripts/bluetooth_acceptance.sh` and `./scripts/protected_acceptance.sh` passed;
- `hyprctl configerrors` returned no errors;
- DP-1 owned one `titonium-menubar` and one `titonium-dock`; DP-3 owned no Titonium layer;
- the reference shell remained running on DP-3 while one Titonium daemon was restored on DP-1;
- Hyprland hashes remained `97f9e0f8…451e9` (live) and `3df33e52…880a` (dotfiles).

Run the static and syntax checks from the project root:

```bash
./scripts/check.sh
bash -n scripts/dock_acceptance.sh scripts/bluetooth_acceptance.sh scripts/protected_acceptance.sh
git diff --check
```

The focused read-only live scripts are:

```bash
./scripts/dock_acceptance.sh
./scripts/bluetooth_acceptance.sh
```

`dock_acceptance.sh` reads `dock state`, checks the DP-1 Dock layer and rejects Titonium layers
on DP-3. `bluetooth_acceptance.sh` reads Bluetooth state, opens/closes the DP-1 popup, verifies
mutual exclusion with Spotlight and Center Notch, and checks DP-3 isolation. Both scripts launch
and clean up their own temporary foreground shell, call no mutating Dock/Bluetooth IPC, and verify
repository and Hyprland-file isolation. `protected_acceptance.sh` includes both focused scripts.
The controller should also run:

```bash
./scripts/smoke.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
```

Stop only the existing Titonium shell using its shell ID before foreground acceptance, then leave
one daemon for the user's review:

```bash
qs -p /home/cole/Projects/titonium kill
qs -p /home/cole/Projects/titonium
qs -d -p /home/cole/Projects/titonium
```

### Manual Dock and Bluetooth checkpoint

Audio checkpoint: on DP-1 (scale 1.5), verify the corrected popup's
right-edge anchoring, bounded height and exactly-once outer padding; exercise Output/Microphone
controls, local slider drag, playback stream updates, click/outside-click/Escape close and the
focused-screen click-through OSD. Confirm DP-3 continues to belong only to the reference shell.
Restore original volume, mute state and runtime preference.
Approve this Audio checkpoint first. Then on DP-1 (scale 1.5), verify Dock body/icon/margin/
spacing of 56/40/8/6 logical px, 4px edge reveal, bounded 1.12 hover scale and 4px lift, solid
Neutral Utility rendering, click-through outside the mask, auto-hide on a populated workspace,
empty-workspace visibility, pin control and 64px pinned reservation versus zero auto-hide reserve.
Exercise Applications-to-Spotlight routing, pinned/running grouping, focus/launch/cycle behavior,
right-click menu actions, keyboard order, focus return and urgent/running indicators. Confirm DP-3
has no Titonium Dock layer or exclusive zone.

Before touching Bluetooth, capture the original host state. The following is a read-only evidence
capture; it is intentionally outside Titonium's runtime and writes only `/tmp`:

```bash
evidence=/tmp/titonium-native-dock-bluetooth-pre.txt
{
    date -Is
    echo '## git status'
    git -C /home/cole/Projects/titonium status --short
    echo '## Hyprland hashes'
    sha256sum /home/cole/.config/hypr/hyprland.lua \
        /home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua
    echo '## Titonium processes'
    pgrep -af '[q]s' || true
    echo '## Bluetooth adapter and discovery state'
    bluetoothctl show
    echo '## Connected devices'
    bluetoothctl devices Connected
    echo '## Paired devices (reference for forget checks)'
    bluetoothctl paired-devices
} > "$evidence"
```

Record the `Powered:` and `Discovering:` values and the connected addresses from that file before
manual testing. Verify unavailable/off/on/scanning states, section ordering, connect/disconnect,
one safe pairing flow where supported, and the inline two-step Forget confirmation. Do not use
automated acceptance to power, scan, pair, connect, disconnect or forget a device.

Restore the original state explicitly after the checkpoint: disconnect any device that was not in
the captured connected-address list; reconnect every captured address; set adapter power to the
captured `Powered:` value; and set discovery to the captured `Discovering:` value. The manual
commands are, as applicable:

```bash
bluetoothctl disconnect AA:BB:CC:DD:EE:FF
bluetoothctl connect AA:BB:CC:DD:EE:FF
bluetoothctl power on     # or: bluetoothctl power off
bluetoothctl scan on      # or: bluetoothctl scan off
```

Re-check `bluetoothctl show` and `bluetoothctl devices Connected` against the evidence file. If a
pairing/forget test changed a real device, restore that pairing manually before continuing. Do not
start Network/Wi-Fi implementation; the Wi-Fi glyph remains diagnostic until this checkpoint is
approved.

## Runtime gate

Stop any daemon using the same shell ID, then run:

```bash
./scripts/smoke.sh
./scripts/protected_acceptance.sh
./scripts/center_notch_acceptance.sh
./scripts/audio_acceptance.sh
hyprctl configerrors
```

Smoke requires `Configuration Loaded` and rejects QML type/load/runtime errors. Protected
acceptance uses IPC to exercise Spotlight scope/query/close transitions, confirms repository
isolation and verifies both Hyprland configuration hashes. It does not launch an application or
write clipboard content.

Center Notch acceptance opens Overview, Tools and Session through IPC, proves that Spotlight closes
the notch, and closes both surfaces again. It rejects runtime type/load errors, repository writes
and changes to either Hyprland configuration hash. Mock tiles are deliberately not executable and
there is no action IPC endpoint.

Audio acceptance launches one foreground shell and calls only `audio.state`, `audio.popup`,
`audio.closePopup`, `audio.popupState`, `audio.osdState`, Center Notch and Spotlight lifecycle IPC.
It checks state formatting, idle OSD, popup mutual exclusion, clean runtime logs, repository
isolation and both unchanged Hyprland configuration hashes. It never calls or exposes volume,
mute, adjustment, OSD-show or device-selection IPC.

After passing, restart with `qs -d -p /home/cole/Projects/titonium` and manually verify the assigned
Titonium output:

- exactly one 40px bar with correct scaling/exclusive zone on DP-1 and no Titonium surface or
  exclusive zone on DP-3;
- workspace interaction and input-method state;
- `Super + Space`, typing, Tab/Shift+Tab scopes, category paging and Escape;
- `Super + V`, Clipboard navigation and close;
- unplug/replug or focus another monitor without a stranded overlay.
- open the compact Center island on DP-1 scale 1.5 and DP-3 scale 1.0;
- confirm true centering, top attachment, 48px rail proportions and outside-click/Escape close;
- switch pages rapidly and confirm only the latest page remains, without vertically stretched tiles;
- activate a Tools/Session tile and confirm translated feedback with no system action.

Audio remains awaiting visual approval. On DP-1 (scale 1.5), verify the Audio
icon remains visible when diagnostic glyphs collapse; click/outside-click/Escape popup lifecycle;
right-edge anchoring and bounded height; Output/Microphone controls and local drag behavior; and
playback applications appearing/disappearing without closing the popup. Verify multimedia-key or
external volume changes update the Bar and produce one focused-screen, bottom-centered,
click-through OSD that coalesces changes, unloads after 1.2 seconds and does not flash at startup
or output hotplug. Confirm the default 100% cap and a prepared v6 runtime fixture's 150% cap, then
re-check Spotlight, Input Method and Center Notch. Restore the original volume, mute state and
runtime preference before review. DP-3 must remain free of Titonium surfaces throughout.

Every imported module adds a pure fake-driven test, an architecture check and a focused live test
for its own boundary. Never automate power actions, destructive session actions, real application
launch or clipboard writes.
