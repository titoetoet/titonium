# Idle and Compact implementation

Updated 2026-09-05 to the locked three-tier design in
[the specification](superpowers/specs/2026-09-05-center-island-idle-compact-design.md).
This replaces the earlier four-tier first-pass delivery notes.

## Delivered

- Connected retains the existing top-attached notch and curved shoulders for Idle
  and Compact. Classic retains the oval. Shared activity controls are unchanged.

- Idle retains the sleeping QML Pig, contained hover reactions and Settings appearances.
- Compact selects only Privacy, Focus and Media. Operations, agents, jobs, generic
  timers and notifications do not compete for Compact slots. Other shell services
  and existing Banner/Expanded presentation remain available.
- Three-way default is Privacy Primary, Focus Satellite, Media hidden. Manual swaps
  persist through routine updates; a newly detected privacy session reclaims Primary.
  Ending one of overlapping recordings does not restart the remaining occurrence.
- Focus now has a real session countdown, tabular digits and a depleting Satellite
  ring. It expires automatically. Existing daily-focus text remains a separate fallback.
- Primary Media shows four muted frequency bars and a cleaned title; Satellite shows
  three bars. Bars are 3px wide, 2px apart, centered, and damped over 160ms within
  3–14px. Pause, silence and Reduced Motion settle to short bars.
- Primary titles cap at 200px with an alpha fade; overflow scrolls on hover/focus only.
  A 1.8s glyph-masked shimmer runs only on the playing Primary title, stopping for
  pause, Reduced Motion or hover scrolling.
- Wheel input over Media alone changes the selected MPRIS player's volume by 5%
  per wheel notch, clamped to 0–100%. Unsupported volume control is a no-op;
  stale player identities are rejected. It never changes system volume as a fallback.
- Satellite has a stable chip hit area and hover/focus feedback inside one capsule.
- Right-click Privacy opens a themed lightweight menu of available actions. It opens
  neither Banner nor a swap. Session replacement/closure closes an obsolete menu.
- Supported recording action gracefully stops the detected owned `wf-recorder`
  process identities using pidfds and start-time validation. It cannot target a reused PID.
- PipeWire microphone capture streams provide per-stream mute/unmute. Stream identity
  is rechecked before mutation; this does not mute unrelated microphones/streams.
  Monitor/loopback peak-analysis streams are excluded from microphone detection.

## Current provider boundaries

Privacy detection covers `wf-recorder` and PipeWire audio capture streams. Generic
portal screen sharing and other recording tools still need dedicated providers; there
is no speculative stop action for an unsupported application.

The audio bars measure four frequency bands of the default output, including other
sounds mixed into that output. They are not isolated per-track data. Volume control
remains strictly player-specific. The service requires Python 3 and `parec`, captures
only an explicit output monitor, and never persists PCM. Missing capture produces
still bars. The controller stops capture when media is hidden, paused or Reduced
Motion is enabled; shutdown also terminates the capture child.

Focus can be started through the existing shell IPC transport:

```sh
qs -p /home/cole/Projects/titonium ipc call focus start 1500
qs -p /home/cole/Projects/titonium ipc call focus state
qs -p /home/cole/Projects/titonium ipc call focus cancel
```

A new Focus launcher/management screen is not included; Banner/Expanded design stays
deferred. Focus is session-only and clears when the shell restarts.

## Geometry

Topbar height is configurable from 40–64 logical pixels. Capsule height is Topbar
minus 8. Idle is 2.4 capsule heights wide; Compact follows measured content, clamped
between max(3 heights,7.5% screen width) and max(minimum,25% screen width), then bounded
to usable screen width. Long media titles fade; timer digit changes retain the same width.

## Verification

- Full `scripts/check.sh`, including QML lint and behavioral tests: passed.
- Qt UI tests cover cleaned media titles, four/three frequency bars, hover scrolling and shimmer, Reduced Motion, Focus
  countdown/ring/session expiry, scoped wheel input, click/swap separation, Privacy
  menu lifecycle and unchanged Idle hover behavior.
- Controller tests cover audio-monitor activation, hidden/reduced-motion shutdown,
  stale volume contexts, stale Privacy sessions and existing notification deadlines.
- Isolated Wayland foreground smoke and protected acceptance: passed. The latter
  skips native notification D-Bus ownership because the resident shell owns it.
- Live isolated Focus start/countdown/cancel: passed; screenshot
  `/tmp/center-three-tier-focus.png`.
- Live Privacy right-click using a non-destructive fixture: popup opened successfully
  on Wayland; screenshot `/tmp/center-three-tier-menu.png`.
- Hyprland configuration errors: empty. No real recordings were stopped, no user
  microphones muted, no clipboard changes and no resident-shell settings changes.

## Integration references

AudioService remains the native PipeWire owner and provides the selected output name.
MediaSpectrumService owns the output-monitor subprocess and four-band FFT. A single
controller binding controls demand across Classic and Connected.

- [Qt Menu](https://doc.qt.io/qt-6/qml-qtquick-controls-menu.html): separate-window popup, with a real input event required for the Wayland grab.

## Resident-shell verification (2026-09-05)

Restarted from the project after user authorization. Current instance `ng84241wkt`,
PID 197591. Live verification covered Focus countdown, Media/Focus Satellite swap,
title-only media, Primary opening Banner, and Idle hover/return to sleep. A live
screenshot exposed silent bars sitting low; fixed by reserving a 20px visualizer
row and added an assertion for its center alignment. Full check.sh passed afterward.

A temporary MPRIS fixture exercised discovery and layout without opening a player.
It emitted property-format warnings for optional fixture fields; these were fixture
limitations. Native volume support was confirmed, but the virtual pointer's scroll
events did not reach even an isolated non-mutating WheelHandler fixture. Desktop
wheel volume therefore remains unverified; Qt UI scoping and MPRIS action tests pass.
No audible playback was started, so live sound-reactive movement was not exercised.
All Focus/media fixtures were cleared; the pointer was restored and only the resident
Titonium instance remains. Hyprland reports no configuration errors.

## Connected notch restoration (2026-09-05)

Per user correction, Connected uses the existing ConnectedPillShape shoulders in
both Idle and Compact. Shared capsule content remains centered inside the notch;
painted/input bounds include its shoulders and top attachment. Classic stays oval.
Full check.sh and isolated smoke passed. Live Idle and Focus screenshots verified
the shape: `/tmp/center-connected-notch-idle.png` and
`/tmp/center-connected-notch-focus.png`. Test Focus was cancelled; resident instance
`0kb4gq1wkt` (PID 201600) is running with clean startup logs.
Protected acceptance passed on retry; the first run had a transient Spotlight input
mismatch (`firelo` versus expected `fire`). Native notification ownership was skipped
because the resident shell owns D-Bus, as in earlier isolated runs.

## Earlier visualizer styling (superseded by the four/three-band refinement)

Five coordinated colors use darker variants on light themes. Bars are 2.5px wide
with rounded ends. A power curve lifts quieter measured peaks; a 140ms bounded
bounce adds movement on level changes. Brightness rises with amplitude. Silence,
paused playback and Reduced Motion settle to short still bars. Real audio remains
the only production input; preview fixtures use explicitly simulated samples.
Full check.sh and the 12-case Compact UI suite passed.
Runtime smoke and protected acceptance passed after this styling update. Resident
instance `t7g4t72wkt` (PID 207641) is running the new design. Actual Chromium playback
was active during the final check; live screenshots were captured at
`/tmp/center-color-live-a.png` and `/tmp/center-color-live-b.png`.

## Four/three-band refinement (2026-09-05)

Supersedes the colorful five-bar styling above. Primary now uses four FFT frequency
bands, Satellite three. Compact titles remove release tags and delimiter suffixes,
fade at 200px, and scroll only on hover/focus. Shimmer applies only to the playing
Primary title and pauses during scrolling or Reduced Motion.

Full check.sh and the 13-case native Compact UI suite passed, as did isolated smoke
and protected acceptance. Known-tone FFT and explicit monitor-only capture tests
passed. A live capture emitted valid four-number frames and terminated its child
cleanly. Read-only review found no actionable bugs.

Resident instance `wwp4xr3wkt` loaded successfully; live MPRIS discovery and the
output-monitor capture process were confirmed. Final desktop screenshots could not
be captured because the session was locked and both monitors were powered off.
No attempt was made to unlock the session. Visual appearance on the live desktop
still needs inspection after unlock. Earlier screenshot evidence describes earlier
revisions only.
