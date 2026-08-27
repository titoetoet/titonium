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

Audio remains awaiting visual approval. On DP-1 (scale 1.5) and DP-3 (scale 1.0), verify the Audio
icon remains visible when diagnostic glyphs collapse; click/outside-click/Escape popup lifecycle;
right-edge anchoring and bounded height; Output/Microphone controls and local drag behavior; and
playback applications appearing/disappearing without closing the popup. Verify multimedia-key or
external volume changes update the Bar and produce one focused-screen, bottom-centered,
click-through OSD that coalesces changes, unloads after 1.2 seconds and does not flash at startup
or output hotplug. Confirm the default 100% cap and a prepared v6 runtime fixture's 150% cap, then
re-check Spotlight, Input Method and Center Notch. Restore the original volume, mute state and
runtime preference before review; do not start Bluetooth until that review approves Audio.

Every imported module adds a pure fake-driven test, an architecture check and a focused live test
for its own boundary. Never automate power actions, destructive session actions, real application
launch or clipboard writes.
