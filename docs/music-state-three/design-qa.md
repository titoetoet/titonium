# Music state 3 — implementation QA

Final visual acceptance: **passed on the actual desktop, 2026-09-06**.
See `live-test-2026-09-06.md` and `live-2026-09-06.png` for real UI clicks,
playback results and GPU capture. The earlier capture timeout is resolved.
Up Next is unsupported by Chromium; its supported TrackList path passed the
separate native private-DBus test.

## Delivered

- Current artwork, metadata, transport and seeking inside one themed surface.
- Measured 24-band output spectrum above Up next; no volume control.
- Content-based width and narrow reflow in Connected and Classic renderers.
- Optional real MPRIS TrackList metadata with unavailable/end states.
- Seek release revalidates player and track identity. Hidden media stops details
  observation; periodic position changes do not crossfade the player.

## Evidence

- `./scripts/check.sh`: passed, including qmllint and music rule/service tests.
- `python3 scripts/check_music_ui.py`: 9 passed, covering transport capability,
  seek release, track changes during dragging, reflow, silence and reduced motion.
- `./scripts/smoke.sh`: passed in an isolated checkout to avoid conflicting with
  the already running Titonium instance.
- `./scripts/protected_acceptance.sh`: passed in that isolated checkout.
- `hyprctl configerrors`: empty output, exit 0.
- Reviewer identified a TrackList startup subscription race. Added a regression
  that failed before the fix and passed after refreshing on monitor readiness.

`reference.png` is the approved design. `implementation.png`, `narrow.png`,
`unavailable.png`, `light.png` and `silence.png` are QML fixture captures with
production Music components, Shared controls and Theme. Their metadata and
spectrum are test inputs. Only the native ClippingRectangle boundary is replaced
in qmltestrunner, so these captures do not validate rounded artwork clipping.
`preview-cover.png` is fixture artwork only; production uses the player's artwork.

Compared with the reference, the implementation retains the approved hierarchy,
inside-only layout and visualizer-over-queue arrangement, using Titonium's actual
colors, type and controls. No native GPU screenshot is presented as verified.

To finish visual acceptance on an unlocked desktop:
`python3 scripts/check_music_ui.py --native --wayland`, then inspect `native.png`
for artwork clipping and spacing. Also open Music from Compact with a real playing
track to verify the native player integration visually. Players without TrackList
cannot supply Up next; the UI explicitly displays that limitation.

## Follow-up fixes after user feedback

- Reduced natural width from 700–780 to 584–624 logical pixels and height from
  184 to 152; retained content sizing and narrow reflow. Artwork is now 88px.
- Reused the standard secondary button, 17px title token, 12px surface radius
  and 8px button radius. Removed the bespoke white 48px pause disk.
- Fixed capability-only updates leaving transport actions disabled. Production
  MprisService now listens for toggle/previous/next capability changes.
- Fixed real Up next rejection: Quickshell exposes object-path metadata as a
  QVariant string while busctl returns a plain path. Normalize at the service
  boundary before matching track IDs.
- Removed the detail snapshot dependency from details demand to break the
  live `mediaDetailsVisible` binding loop. Opening/closing Center after restart
  emits normal focus logs without that warning.
- Added `python3 scripts/check_music_native.py`: a private DBus fixture with actual
  Quickshell MPRIS, production Music buttons, adapter and service. It reproduced
  both disabled capability updates and missing Up next before fixes, then passed.
  The endpoint recorded Previous, Pause, Next and SetPosition. No real media app
  is launched or controlled. This requires a C++ compiler, Qt6Core/Qt6DBus and
  permission to create private Unix sockets. Native pointer hit-testing is covered
  only by the separate QML interaction fixture, not the DBus activation test.
- Re-ran check.sh, 9 QML interaction tests, isolated smoke/protected acceptance;
  all passed. Hyprland configuration errors remain empty.

The only real source available during this check was stopped Chromium, reporting
all transport capabilities false and no TrackList interface. Its Up next cannot
be inferred from MPRIS; a source-specific integration would be needed. The current
UI retains its honest unavailable state for that source.

## Connected style completion

See `connected-morph.md` for restored shoulders, continuous title and shared-window
state transitions, including lifecycle regressions and final passing gates.
