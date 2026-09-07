# Music state 3 implementation plan

**Goal:** Implement the approved all-inside Music design, with no volume control,
balanced cover/transport layout, measured spectrum above Up next, and content-sized geometry.

**Spec:** User-approved image `exec-0c8a0d36-c4d8-47b0-b6b0-535782ac2a6a.png`
from the current design conversation. This supersedes the earlier music mockups.
State 3 is the existing banner reached by activating Compact. Expanded reuses the
same music content; other application geometries remain unchanged.

**Architecture:** Add a reusable value-driven MusicPlayerContent under Bar/center.
Connected and Classic load it only for an open media context. Existing MprisService
owns transport and seek. A read-only TrackList helper supplies optional upcoming
metadata; unsupported or shuffled queues show an honest unavailable state.
MediaSpectrumService retains one output-monitor capture with four compact bands
plus 24 measured spectrum bands. No synthetic animation or native view ownership.

**Tech stack:** QML/Quickshell, JavaScript rules, Python standard library, busctl/dbus-monitor.

## Tasks (executed inline in the current checkout to preserve in-progress code)

- [x] Add failing behavior tests for width clamping/reflow, seek identity validation,
  missing/invalid track metadata, queue ordering and measured spectrum bands.
- [x] Implement media rules and services. Read installed MprisPlayer qmltypes:
  native position is `position`, not `trackPosition`; gate writes on canSeek and
  positionSupported and revalidate identity plus uniqueId at release.
- [x] Add themed content, rounded cover with icon fallback, accessible transport,
  drag-safe seeking, live spectrum, and optional next track metadata.
- [x] Integrate lazy content into both renderers and preserve other contexts and
  existing close/focus policies. Size Music from content within viewport bounds.
- [x] Run new tests, scripts/check.sh, smoke.sh, protected_acceptance.sh and
  hyprctl configerrors; render real QML in an isolated offscreen fixture when the
  live compositor is inaccessible. Document exactly which checks are blocked.

## Source decisions

Reuse Titonium's Shared.Button, Shared.Slider, Theme and existing renderers; no
external implementation is copied. Quickshell installed qmltypes and official
MprisPlayer documentation are the native API reference:
https://quickshell.org/docs/v0.2.0/types/Quickshell.Services.Mpris/MprisPlayer/
Quickshell does not expose TrackList. The helper uses the standard optional MPRIS
TrackList DBus interface directly, subscribes to changes, and never writes to it.
https://specifications.freedesktop.org/mpris-spec/latest/Track_List_Interface.html

## Validation outcome

Behavior, layout, lint, isolated smoke and protected acceptance passed. Native GPU
visual acceptance remains blocked by the locked/DPMS-off session. See
`../../music-state-three/design-qa.md` for the fixture boundary and checks.
