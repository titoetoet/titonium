# Right Pill Connectivity Notches Design

**Date:** 2026-09-04  
**Status:** Approved in chat; awaiting written-spec review

## Goal

Make the Wi-Fi, Bluetooth and Audio controls in the right Top Bar pill open as connected notches,
using the same control-anchored silhouette and reversible motion already used by the Input Method
and Active Window menus. Preserve the existing popup content, service contracts, IPC behavior,
screen policy and mutual-exclusion rules.

## Current structure

Input Method and Active Window menus are rendered by one always-mounted `EdgeMenuWindow` per
eligible screen. `EdgeMenuSurface` owns the compact left/right silhouettes, keeps the compact
island content visible, derives an animated branch from a control anchor and clips menu content
inside that branch.

Wi-Fi, Bluetooth and Audio instead open descriptors through `SurfaceManager`. `OverlayHost`
loads their full-screen popup surfaces, and each popup paints an independent `Shared.Panel` below
the Top Bar. This detached ownership means simply changing the panel background cannot produce a
single reliable notch: two layer windows would overlap at the right pill, compact icons could be
covered, and the visible geometry and input mask could disagree.

## Chosen architecture

`SurfaceManager` remains the sole lifecycle and mutual-exclusion owner for Wi-Fi, Bluetooth and
Audio. Their descriptors gain explicit connected-Bar metadata: a boolean ownership marker and a
stable anchor name (`network`, `bluetooth`, or `audio`). The descriptor still carries the popup
source, owner ID, screen, keyboard-focus policy and invoker when available.

`EdgeMenuWindow` becomes the visual owner for descriptors marked as right-pill-connected.
`EdgeMenuSurface` observes the active descriptor for its own screen and loads the existing popup
surface inside its full-screen owner. `OverlayHost` excludes those descriptors from its Loader,
ensuring exactly one visual and input owner. Descriptors without the marker continue through the
existing Overlay lifecycle unchanged.

The feature popup surfaces become content-only views when loaded by `EdgeMenuSurface`. They expose
their natural content size and render only their existing Network, Bluetooth or Audio content,
without a second panel background, entrance transform, full-screen outside-click layer or
independent close animation. All existing coordinator and IPC entry points route these three
features through the connected right-pill owner; there is no detached fallback presentation.

## Anchors and geometry

`ConnectivityPill` exposes screen-local anchor facts for all three controls. `EndIsland` forwards
those facts to `EdgeMenuSurface` without transferring service ownership. The selected descriptor's
anchor name chooses the source rectangle.

The existing `EdgeMenuGeometry.branchRect` and `Shared.AnchoredMenuPillShape` remain canonical.
The connected popup uses the right edge, starts its branch at 28 logical pixels and overlaps the
36-pixel compact pill by 8 pixels. Branch width is the larger of the popup content width and the
source-control width plus 32 pixels, bounded to 240–520 pixels. Height is content-adaptive,
bounded by available output height and 440 pixels. Geometry clamps to a 12-pixel output margin.

Only the right pill expands its inner shoulder toward the branch. The selected compact control
follows any horizontal displacement caused by output clamping; unrelated controls stay in place.
The right compact pill, its icons and the notch are drawn in the same `EdgeMenuWindow`, so there
is no connector rectangle, duplicated background, nested card or seam.

## State and transitions

`RightPillCoordinator` gains a connected-surface presentation path in addition to its existing
System Tray menu path. It projects one selected source, anchor and screen into the same compact ↔
open transition. Opening a connected descriptor prepares `SurfaceManager` first, then assigns the
right visual owner. Failure to open the descriptor leaves the pill compact.

Open uses the existing 240 ms damped transition; close uses the reversible 190 ms transition.
Reduced Motion commits immediately. During opening, compact controls remain interactive until the
existing handoff threshold; popup content becomes interactive after it. Content fades and moves
slightly downward-to-rest without scaling text or controls.

Closing with Escape, outside click, IPC, monitor change or feature coordinator reverses the same
transition. `SurfaceManager` is cleared only when the close transition finishes so content remains
available during the reverse morph. If the manager closes externally first, the visual owner
retains the last descriptor long enough to finish safely, then clears it. Rapid reopen cancels the
pending close and reverses progress without a dead input interval.

Selecting another Wi-Fi/Bluetooth/Audio/Input control replaces the active right branch through
the existing single-owner mutual-exclusion boundary. Opening Center, Spotlight or Settings closes
the connected popup exactly as current SurfaceManager routing requires.

## Content contracts

The existing popup bodies remain feature-owned:

- Network keeps scan, power, connected/known/available sections and network actions.
- Bluetooth keeps power, discovery, connected/paired/available sections and device actions.
- Audio keeps output/input controls, device selection and expandable playback streams.

Views continue to read their own service singletons and call only existing narrow intent methods.
No native Network, Bluetooth or PipeWire object crosses into Bar code. No service imports a view,
and no new process, persistence or polling owner is introduced.

## Input and accessibility

When compact, `EdgeMenuWindow` exposes only the existing pill regions. While opening or closing,
its mask contains the compact right pill and animated branch. When open, it also accepts the
full-screen outside-click layer. `OverlayHost` publishes no competing region for a descriptor
owned by the Bar.

Keyboard focus remains exclusive while the connected popup is open. Escape closes it. Focus is
returned to the original invoker where available. Existing accessible names, headings, button
roles and keyboard traversal inside each popup remain intact.

## Failure handling

- Missing screen, source or anchor: fail closed and do not start the morph.
- Popup Loader error: close the matching SurfaceManager owner and return to compact.
- Source control disappears: close using the last valid frozen anchor.
- Screen/monitor ownership changes: use existing SurfaceManager close-on-monitor-change behavior.
- Feature data becomes unavailable: retain the popup's existing unavailable presentation.
- External close during animation: finish the reverse transition once and clear frozen state.

## Files and boundaries

Expected implementation areas:

- `Titonium/Bar/islands/ConnectivityPill.qml`: publish three control anchors and route Audio with
  an invoker.
- `Titonium/Bar/islands/EndIsland.qml`: forward anchor facts.
- `Titonium/Bar/right/RightPillCoordinator.qml`: coordinate connected descriptors and close
  completion.
- `Titonium/Bar/right/EdgeMenuSurface.qml`: select anchors, own the connected Loader and reuse the
  existing branch geometry/content transition.
- `Titonium/Bar/right/EdgeMenuWindow.qml`: derive focus and input ownership for connected surfaces.
- `Titonium/Core/Surfaces/OverlayHost.qml`: exclude Bar-owned descriptors.
- `Titonium/Overlays/{Network,Bluetooth,Audio}`: add descriptor metadata and embedded presentation
  to existing coordinators/surfaces.
- Narrow pure/static checks under `scripts/` and registration in `scripts/check.sh`.

No service API, IPC target, i18n catalog, Hyprland configuration or unrelated popup is changed.

## Verification

Test-first contracts cover:

- the three stable anchor names and descriptor routing;
- exactly one Loader/visual owner for connected descriptors;
- correct source-anchor selection and right-branch clamping;
- compact/menu input handoff and delayed lifecycle cleanup;
- no nested popup panel/background in embedded mode;
- Audio receives an invoker just like Network and Bluetooth;
- external close and rapid reversal normalize to a single compact state.

Run the focused static checks first, then `./scripts/check.sh`, `./scripts/smoke.sh`,
`./scripts/audio_acceptance.sh`, `./scripts/bluetooth_acceptance.sh`,
`./scripts/wifi_acceptance.sh`, `./scripts/protected_acceptance.sh` and
`hyprctl configerrors`. Live acceptance remains read-only with respect to real network, Bluetooth
and audio state.

Manual review on DP-1 at scales 1.0 and 1.5 verifies each control grows from its own anchor, the
right pill remains visually continuous, the opposite pill does not move, content is not clipped,
and Escape/outside click/direct switching animate without seams or dead input regions.

## Non-goals

- Redesigning popup content or adding new Network/Bluetooth/Audio behavior.
- Moving device/service ownership into the Bar.
- Changing Dynamic Island behavior.
- Generalizing every Titonium overlay into a notch.
- Editing either Hyprland configuration file.
