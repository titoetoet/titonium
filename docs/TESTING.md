# Testing

## Static gate

`./scripts/check.sh` validates shipped JSON/i18n, protected keybinds, source shape, service and bar
boundaries, preference projection, pure Application/Clipboard/Spotlight behavior and every QML file
with `qmllint`.

The Bar gate also validates true-center geometry, Dynamic Island state/transition fixtures,
immutable mock catalogs, locale-key parity and idle safety. `Timer`, shaders, `MultiEffect`, infinite
animation, executable mock boundaries and future connectivity-service imports are rejected.

The Audio contract gate additionally enforces the sole PipeWire owner, tracker-backed normalized
view contract, no repeating Audio timer, no raw audio mutation outside `Services/Audio`, no command
or future-service dependency and no mutating Audio IPC. Popup content must remain in the existing
`OverlayHost` lifecycle; the click-through OSD Loader must be tied to the active coordinator and
its owner screen.

The notification gates enforce one native `NotificationServer`, exact immutable descriptor fields,
100-history/three-toast/16-critical bounds, session-only unread transitions, policy precedence,
standard-action value projection, DP-1-only toast ownership and lazy stack/panel lifecycle. Pure
fixtures cover passive versus critical routing, FIFO completion, hover deadline pause/resume,
custom overrides, stale/lost-screen panel cleanup, Connected right-pill history presentation,
Classic detached history presentation, the fixed Topbar history glyph/order, Center-only bell
wobble, and shoulder-free Classic Center. No view imports the native Notifications module, and the
public IPC surface remains `notifications state|markRead` with read-only metadata.

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

### Selectable Top Bar styles

The Top Bar focused checks cover the `modules.bar.style` default and normalization, Settings
projection, Connected-versus-Classic popup routing, Classic composition, right-pill ownership,
control-anchor geometry, and style-switch cleanup. They reject a Classic default, an unknown value
that does not normalize to Connected, Connected descriptors loaded by `OverlayHost`, simultaneous
style hitboxes, swapped Network/Bluetooth anchors, and a stale close that clears a newer owner.

Run the focused static set before a visual review:

```bash
node scripts/check_preferences.js
python3 scripts/check_settings_pages.py
node scripts/check_bar_popup_routing.js
node scripts/check_classic_bar.js
node scripts/check_connected_popup_content.js
node scripts/check_edge_menu_geometry.js
node scripts/check_right_pill.js
node scripts/check_top_bar_style_lifecycle.js
node scripts/check_notification_theme_contract.js
python3 scripts/check_wifi.py
python3 scripts/check_bluetooth.py
python3 scripts/check_audio.py
python3 scripts/check_surface_passthrough.py
```

The two manual modes are intentionally separate and do not mutate real Wi-Fi, Bluetooth, or Audio
state. In Settings preview, switch Connected → Classic and Cancel, then repeat Connected → Classic
and Apply. In Classic, verify the detached pill gaps and detached Network, Bluetooth, Audio, and
System Tray popups. Return to Connected and verify Wi-Fi, Bluetooth, and Audio grow from their own
right-pill anchors. In both modes check Escape, outside-click, control switching, a style switch
while a popup is open, and scales 1.0 and 1.5. This is a visual checkpoint; do not record it as
passed until someone has performed the review.

For the themed Notification Center review, verify in Classic that compact, banner, and expanded
Center never show shoulders. In both styles, verify the rightmost Topbar control remains the fixed
non-bell history glyph across unread changes, and that a new unread notification presents the bell
and any wobble only in the non-interactive Center secondary pill. The primary pill must remain
behaviorally unchanged; the secondary pill must sit outside it with an 8dp gap and four rounded
corners, and Center must not gain a satellite mode. In Connected, open history from
that exact control and verify one continuous right-pill chassis; in Classic, verify the detached
overlay. Check same-control, outside-click, and Escape close paths; switch styles while it is open
to confirm no ghost surface or stale input mask remains; then enable Reduced Motion and confirm state
remains unchanged while transition motion is removed. The critical FIFO Center-banner path is
unchanged.

For Classic Center, also verify the compact pill remains visible while a banner or expanded popup
is open and that repeated compact ↔ popup transitions do not create, destroy, or remap a native
Center window. Compact input must be limited to the combined pill bounds; an active popup uses
fullscreen input only for outside dismissal, and closing input is limited to still-painted content.

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

### Manual edge-menu checkpoint

Click an Active Window app with DBusMenu and verify the menu grows from the left pill. Open Input
Method and verify the same menu chassis grows from the right pill. In both cases the opposite edge
must remain compact. Check Escape, click-outside, submenu Back, normal actions, checkbox/radio,
source disappearance, rapid reopen and scale 1.0/1.5. Center, Spotlight and Settings remain mutually
exclusive with either edge menu.

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

Center acceptance verifies the `CenterSurfaceHost` namespaces and compact/banner/expanded lifecycle,
proves that Spotlight compacts Center, and closes both surfaces again. It rejects runtime
type/load errors, repository writes and changes to either Hyprland configuration hash. Notification
history remains coordinator domain data; the Topbar Notification Center owns its history entry point,
while Center has no history page. The historical `centerNotch` IPC target is retained for acceptance compatibility;
its state/result vocabulary is neutral mode state rather than a theme or page contract.

Audio acceptance launches one foreground shell and calls only `audio.state`, `audio.popup`,
`audio.closePopup`, `audio.popupState`, `audio.osdState`, Center and Spotlight lifecycle IPC.
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
Job and Timer entries. It verifies immediate Activity-first presentation, the ranked
`Timer → Important Job → Normal Job → Timer` loop, progress replacement, Attention pause/resume
with a fresh dwell interval, exact cleanup back to Daily Focus and the unchanged Center Notch
lifecycle. It creates no process scanner or user runtime activity and restores all fixture state
in its exit trap. Run it directly with:

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

Notification acceptance never stops a resident Titonium shell: because
`org.freedesktop.Notifications` has one session owner, it reports a skip when that shell is already
running. With the name free, it starts one foreground shell and sends controlled normal and critical
`notify-send` fixtures. It verifies DP-1-only passive toast ownership, history/unread preservation,
the read-only panel/queue/policy state seam and the four-second critical FIFO route. It drives the
existing `titonium:notifications` global shortcut to verify owner mount, mark-read timing,
same-control teardown and reopening; existing Audio and Spotlight IPC routes provide safe
cross-control owners. The copied runtime settings file is switched between Connected and Classic to
verify both shells and style-change teardown without touching live settings. Before a live fixture
(or a safe D-Bus/Wayland skip), it also runs the read-only themed contract: the Topbar history glyph
stays fixed and rightmost, Center alone owns the bell wobble, and Classic Center has no shoulders.
It rejects runtime errors, repository writes and changes to either Hyprland configuration. It adds no
injection, action, dismissal, panel-control or policy-patch IPC; standard-action and custom-policy
behavior remain deterministic pure/static coverage.

After the focused fixture (or its safe skip), manually verify the assigned Titonium output:

- exactly one 44px bar with correct scaling/exclusive zone on DP-1 and no Titonium surface or
  exclusive zone on DP-3;
- workspace interaction and input-method state;
- `Super + Space`, typing, Tab/Shift+Tab scopes, category paging and Escape;
- `Super + V`, Clipboard navigation and close;
- unplug/replug or focus another monitor without a stranded overlay.
- confirm five Workspace slots and the naturally sized Active Window pill immediately after them;
- open the Active Window pill on DP-1 scale 1.5;
- confirm the popup remains centered, top-attached, keeps 48px rail proportions and closes on outside-click/Escape;
- secondary-click Center and confirm Connected contextual banners morph from the compact pill,
  while Classic banners appear as detached top-centered popups with the Wi-Fi/Bluetooth gap,
  surface color, padding, outline, and entrance/exit motion;
- while a Classic popup opens, close and immediately reopen it; confirm opacity, scale, and
  translation reverse from their current painted values with no jump, duplicate completion, or
  stale Center teardown;
- toggle Reduced Motion during both Classic entrance and exit; confirm motion stops immediately,
  the popup lands on the correct endpoint, and Center remains responsive;
- on a short output, confirm the Classic popup height clamps below the Topbar gap; during animation,
  confirm outside-click follows the transformed painted bounds and the 72px banner keeps title,
  subtitle, and actions inside its single padded row;
- with two eligible test outputs, open/dismiss Classic Center on DP-1 and confirm DP-2 never mounts,
  animates, or completes that transition; repeat a critical FIFO replacement and confirm the visible
  banner content crossfades in place without restarting its popup entrance;
- submit an AI approval and confirm Center opens directly to Expanded, advances queued requests
  in place, and collapses after the final decision;
- with unread notifications, confirm the non-interactive Center secondary compact pill alone presents
  the bell and bounded wobble; the primary pill remains behaviorally unchanged and Center state does
  not gain a satellite mode;
- click the media banner body (outside its buttons) and confirm Connected morphs to the expanded
  canvas while Classic switches between detached popup geometries without compact-pill morphing;
- request a retired page over IPC and confirm it normalizes safely to the expanded canvas.

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
discard confirmation. Settings remains a standalone surface, and Topbar Pin remains separately
clickable; the rewritten Center canvas currently exposes no Settings action.

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
52px top offset. Send low/normal and critical notifications: inspect newest-first passive stacking,
icon fallback, three-line body cap, close control and configured toast expiry; confirm critical
items use the FIFO Center banner with hover pause. The rightmost fixed-glyph Topbar Notification
Center control opens history on the clicked screen, marks it read after it opens, and exposes
standard actions, per-item dismissal and clear-all. In Connected it is one continuous right-pill
chassis; in Classic it is detached. Persisted history remains deliberately out of scope.

## Daily Focus Center checkpoint

Automated coverage consists of the pure priority and Daily Focus fixtures, the neutral Center
domain/host ownership contract, full qmllint gate, foreground smoke and read-only Center
acceptance. Manually verify on DP-1 that the Center reservation remains physically centered, Daily
Focus is projected through the active renderer, and the Pin remains independently targetable.
Also confirm `ActiveWindowPill` remains immediately after Workspaces and requests expanded Center.
DP-3 must remain free of Titonium surfaces throughout.

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

## Notification Center checkpoint

Run `./scripts/notifications_acceptance.sh` only when no resident Titonium instance owns the session
notification D-Bus name; a `SKIP` is the safe result otherwise. The script covers passive toast and
critical FIFO routing without synthetic notification IPC. When Wayland and the notification bus name
are available, the global shortcut exercises Connected and Classic history mount/read/teardown,
same-control toggles, cross-control replacement and temporary-runtime style transitions. Its static
companion covers the Edge-window click-forwarding chain, fixed non-bell rightmost Topbar control,
Center-only bell wobble and a shoulder-free Classic Center. Static fixtures also cover action values,
custom policy, hover pause/resume, panel owner replacement, stale teardown and monitor-loss cleanup.
Manually verify the Notification Center history panel rather than the retired Center history viewport.

## Center presentation checkpoint

`scripts/check_center_notch.js` verifies the compact/banner/expanded state machine, top-two activity
ranking, urgent-event policy, drag thresholds and the single visual-owner contract.
`scripts/center_notch_acceptance.sh` exercises IPC compatibility and the live state loop. Manual
scaled-output review must cover 1.0 and 1.5 scale, the non-interactive secondary notification pill,
successful and cancelled drags, AI persistence, four-second notification dismissal,
Settings/Spotlight mutual exclusion, outside/Escape collapse and exact input-mask alignment.

## Center System Monitoring checkpoint

Run `./scripts/system_monitor_acceptance.sh`. It verifies a legacy Monitoring request normalizes to
Overview and that the detached service remains inactive: no sampling, discovery, GPU-info, storage
or process command may start. There is currently no System Monitoring view to review manually.
