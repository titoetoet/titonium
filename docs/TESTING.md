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

The notification gates enforce one native `NotificationServer`, exact immutable descriptor fields,
100-history/three-toast bounds, session-only unread transitions, DP-1-only Variants, lazy stack
lifecycle and one non-repeating five-second timer per card. The Bell has one mutation only:
`markAllRead()`. No view imports the native Notifications module.

The only allowlisted QML warning is Quickshell 0.3.x metadata marking documented `PanelWindow` as
uncreatable. New warnings are failures. UI code is rejected when it owns `Process`, `FileView` or
raw detached execution.

The screen-policy fixture requires Bar, transient overlays and Audio OSD hosts to share the
`DP-1`-only eligible-screen model. It verifies fail-closed disconnect behavior and reactive
eligibility when `DP-1` returns, preventing Titonium from reserving or drawing on `DP-3`.

Settings contracts additionally enforce one coordinator, one lazy DP-1 host, lifecycle-only IPC,
no native/service ownership in presentation, all eight catalog pages, and v7 transaction/migration
fixtures. Run the isolated lifecycle gate with:

```bash
./scripts/settings_acceptance.sh
```

It seeds v6 settings plus legacy Dock data under temporary XDG data/state/cache roots. It verifies
General/Dock navigation, mutual exclusion with Spotlight and Center Notch, Cancel, exactly one
Settings layer on DP-1, no Titonium layer on DP-3, clean logs, a clean repository and unchanged
live/dotfiles Hyprland hashes. It exposes no Apply or patch IPC and cannot alter the user's runtime.

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
./scripts/notifications_acceptance.sh
./scripts/settings_acceptance.sh
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

Center attention acceptance runs with isolated XDG data, state and cache roots, then calls only
`center.state()` and `center.focusState()`. It requires an empty transient arbiter, the translated
Daily Focus fallback, one `titonium-menubar` layer on DP-1 and no Titonium layer on DP-3. It also
rejects runtime errors, repository changes and changes to either Hyprland configuration hash. The
script never invokes `openScratchpad()`, creates a user focus file or launches an editor. Run it
directly with:

```bash
./scripts/center_attention_acceptance.sh

Center Activity acceptance starts an isolated foreground shell and drives only fixture-prefixed
Job and Timer entries. It verifies the ranked `Focus → Timer → Important Job → Normal Job → Focus`
round, progress replacement, Attention pause/resume with a fresh dwell interval, exact cleanup and
the unchanged Center Notch lifecycle. It creates no process scanner or user runtime activity and
restores all fixture state in its exit trap. Run it directly with:

```bash
./scripts/center_activity_acceptance.sh
```

```

MPRIS acceptance starts an isolated foreground shell and calls only `mpris.state()` and
`center.state()`. It validates the value-descriptor shape, verifies that discovery produces no
startup transient, checks that the passive media indicator exactly matches projected playing state,
and keeps Bar ownership to DP-1. It reports the native player snapshot but never invokes a playback
method or external media command:

```bash
./scripts/mpris_acceptance.sh
```

Notification acceptance stops only Titonium, waits boundedly for its shell ID to be released,
starts one foreground shell and then sends one controlled `notify-send` fixture. It requires one
DP-1 toast and no DP-3 toast, verifies five-second presentation expiry preserves unread state, then
uses the same `markRead()` boundary as the Bell. It rejects runtime errors, repository writes and
changes to either Hyprland configuration. It does not dismiss or invoke notification actions.

After passing, restart with `qs -d -p /home/cole/Projects/titonium` and manually verify the assigned
Titonium output:

- exactly one 44px bar with correct scaling/exclusive zone on DP-1 and no Titonium surface or
  exclusive zone on DP-3;
- workspace interaction and input-method state;
- `Super + Space`, typing, Tab/Shift+Tab scopes, category paging and Escape;
- `Super + V`, Clipboard navigation and close;
- unplug/replug or focus another monitor without a stranded overlay.
- confirm five Workspace slots and the naturally sized Active Window pill immediately after them;
- open the Active Window pill on DP-1 scale 1.5;
- confirm the popup remains centered, top-attached, keeps 48px rail proportions and closes on outside-click/Escape;
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

### Settings Center V1 visual/transaction checkpoint

Back up live `settings.json` and legacy `dock.json` before manual testing. From Center Notch, open
Settings and check the eight pages, 980×700 centering, keyboard focus and unloaded close. Preview
then Cancel appearance, workspace count, Dock mode and toast duration; all consuming surfaces must
roll back together. Repeat and Apply, wait for save completion, restart Titonium and confirm V7
persistence, then restore the captured runtime files.

Also verify Dock mode semantics, pin add/remove/reorder, installed-app visibility, unavailable-ID
removal and hidden-pinned precedence. Escape and close on a dirty preview must show the internal
discard confirmation. Center opens Notch, the rail Settings action opens the standalone surface,
Daily Focus is available only from Overview, and Topbar Pin remains separately clickable.

## Workspace, Switcher, Dock pin and Center pin checkpoint

`scripts/workspace_interactions_acceptance.sh` is a read-only system-state gate. It validates the
public window descriptor shape, Center lifecycle, clean runtime log, unchanged repository and
Hyprland configuration hashes, and Titonium layers on DP-1 only. It does not accept a switcher
selection, change workspace, launch an application, write clipboard contents, or change audio and
Bluetooth state.

After the script passes, manually verify Super+Tab then Super release moves to the selected
window's workspace; the Bar renders exactly five grouped workspace slots with occupied ranges,
active app icon, click and wheel navigation; the Dock pin overlaps its upper-left border without
triggering Applications and repeated pin/unpin leaves typing in the previously focused app; Dock
app hover shows no text tooltip; and the TopBar Center pin survives outside clicks while Escape,
Spotlight and unpin close it. DP-3 must remain owned only by the reference shell. Bluetooth is
intentionally unchanged in this batch and is tested separately by the user.

### Dock Pin exactly-once evidence (2026-08-27)

One manual Pin activation produced exactly one pointer event. The captured transition was
`tap before=true`, `apply assigned=false`, followed immediately by
`file changed before reload=false` and `file changed after reload=true`. The atomic file eventually
contained `pinnedOpen: false`. This selects the runtime-store reload branch: the file watcher read
the previous document while Titonium's own asynchronous atomic save was still completing and
reverted the authoritative in-memory state.

The regression contract now requires `DockStore` to suspend its sole runtime watcher while one or
more self-writes are pending, restore it from both the save-success and save-failure paths, and keep
the immediate in-memory transaction authoritative. No timer, duplicate persistence write or extra
pointer handler is used. Manually verify pin, unpin and pin again each react to one click and that
typing focus remains in the previously focused application.

## Center activity and native toast checkpoint

Automated evidence on 2026-08-27: `./scripts/check.sh`, `./scripts/smoke.sh`,
`./scripts/center_notch_acceptance.sh`, `./scripts/notifications_acceptance.sh` and the full
`./scripts/protected_acceptance.sh` passed. Notification D-Bus ownership resolved to `qs`, the toast
layer appeared only on DP-1, toast count became zero after five seconds while unread stayed one,
and `markRead()` reduced unread to zero.

Manual review: change focus between apps and confirm Center renders the real icon and
`App · title`, elides cleanly up to 520px, and opens its four-rounded-corner popup at the shared
52px top offset. Send one to four notifications and inspect newest-first stacking, icon fallback,
three-line body cap, close control, five-second expiry and the Bell dot. Clicking the Bell must only
clear the dot. Notification Center, actions and persisted history remain deliberately deferred.

## Daily Focus Center checkpoint

Automated coverage consists of the pure priority and Daily Focus fixtures, the Center ownership
contract, full qmllint gate, foreground smoke and read-only Center acceptance. Before starting the
MPRIS slice, manually verify on DP-1 that the combined `CenterIsland + Pin` group remains physically
centered, the Daily Focus text is visually quiet and elides on one line, and one click opens the
configured Markdown handler. Confirm the Pin remains independently targetable. Also confirm
`ActiveWindowPill` remains immediately after Workspaces and still opens Center Notch. DP-3 must
remain free of Titonium surfaces throughout.

## MPRIS Center checkpoint

Automated coverage includes deterministic player ranking, normalized transition fixtures, sole
native-import ownership, full qmllint, foreground smoke and read-only MPRIS acceptance. Before
starting the Timer slice, manually play one track, change track, pause and resume. Verify Center
shows track changes for 6 seconds, pause for 2 seconds and resume for 3 seconds, then returns to
Daily Focus. The small media icon must remain only while playing. Restart Titonium while a player
exists and confirm there is no startup flash; closing/stopping the selected player must not take
over Center. No playback control is expected from the Bar in this slice.

## Center Timer checkpoint

Automated coverage includes absolute deadlines, future-only thresholds, simultaneous countdowns,
exact cancellation, overdue completion, one-shot scheduler ownership and isolated IPC acceptance.
For a manual check, start a short named timer and confirm the passive timer icon appears without
replacing Daily Focus. Completion must take over Center, remove the passive icon and return to
Daily Focus after acknowledgement. Restart Titonium with an active timer and confirm the
session-only timer does not reappear.

## Center external Job checkpoint

Automated coverage exercises the complete explicit Job state machine, malformed and unknown IDs,
normal/important priority bounds, progress silence, exact clear and isolated IPC acceptance.
For a manual check, start a long-running job and confirm the jobs icon remains while progress calls
do not repeatedly replace Daily Focus. Complete, fail and require-action events must use their
policy priorities, and `clear` must remove only the matching active job or terminal event.

## Center Notifications page checkpoint

Run `./scripts/notifications_acceptance.sh` to verify native history, toast expiry, viewed state,
DP-1-only layer ownership and unchanged repository/Hyprland configuration hashes. Then perform the
page interaction check:

1. Send two notifications with `notify-send` while Center is closed; the rail badge shows `2`.
2. Open Center, then Notifications; the badge clears while both newest-first history rows remain.
3. Send another notification while Notifications is visible; it appears first without leaving an
   unread badge.
4. Dismiss one row and confirm only that row disappears.
5. Select Clear all and confirm the page enters its empty state.
6. Switch to Tools and back; the page is recreated lazily without duplicating history rows.

## Center System Monitoring checkpoint

Run `./scripts/system_monitor_acceptance.sh`, then verify manually:

1. Open Center > System Monitoring; Live activates and values appear without a startup zero flash.
2. Confirm CPU/RAM/Disk align in the left column and GPU/VRAM/Network align in the right column.
3. Confirm every icon shares the bar/value line and hover exposes its metric name.
4. Generate CPU/GPU/network load; bars and rates update in place at the expected cadence.
5. Confirm Top processes shows at most five rows and Active mirrors Media/Timer/Job without duplicates.
6. Switch to another Center page; Live stops immediately and no monitoring process remains running.
