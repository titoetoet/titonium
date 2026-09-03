# Top Bar Connected and Classic Styles Design

**Date:** 2026-09-04  
**Status:** Approved in chat; awaiting written-spec review

## Goal

Ship two complete, selectable Top Bar presentation styles:

- **Connected Notch** is the default and current direction. The left and right groups form
  continuous edge pills. Active Window, Input Method, Wi-Fi, Bluetooth and Audio open as
  control-anchored notches connected to their owning pill.
- **Classic Separate Pills** preserves the older Titonium presentation from Git checkpoint
  `0cb73ec`: Arch, Workspaces, Active Window, Center, Notification, Pin, Connectivity and Input
  Method appear as separate pills or the same small groups used by that checkpoint, while feature
  popups drop down as detached windows through `OverlayHost`.

The Classic implementation is restored under new component names. It does not replace, revert or
fork the current Connected implementation in place.

## Source of truth

Commit `0cb73ec` (`checkpoint-baseline`) is the restoration source for Classic layout and popup
behavior. Files are read from that commit and adapted only where required to compile against the
current service, settings, screen-policy and component contracts. Current files are never checked
out from the old revision or overwritten.

The restored layout components are named `ClassicBar`, `ClassicStartIsland`, `ClassicEndIsland`
and `ClassicCenterGroup`; restored popup components use feature-specific
`Classic*PopupSurface` names.
Shared leaf controls are reused only when their current behavior and drawing remain compatible
with the checkpoint. Any leaf whose current implementation assumes a connected owner receives a
Classic wrapper or restored Classic implementation rather than style branches spread through the
leaf.

## User setting

Preferences add one global enum at `modules.bar.style`:

- `connected` — Connected Notch;
- `classic` — Classic Separate Pills.

Missing, malformed and unknown values normalize to `connected`, including all existing runtime
settings. The defaults catalog ships `connected`. The setting appears in Titonium Settings on the
Bar page as a two-choice selector and participates in the existing preview, Apply and Cancel
transaction. Switching the preview changes the visible Top Bar style immediately; Cancel restores
the committed style and Apply persists it atomically.

This is one global style selection. It is not a per-control visibility option and does not permit
mixing Classic pills with Connected popups.

## Composition

`BarSurface` remains the screen-local shell and chooses exactly one presentation tree from the
effective preference:

```text
BarSurface
└── style selector
    ├── connected → current Bar reservations + CenterPillWindow + EdgeMenuWindow
    └── classic   → ClassicBar + classic detached popup routing
```

Only the selected tree paints or contributes Top Bar input regions. Connected always-mounted
owners remain instantiated for stable screen lifecycle, but while Classic is selected they
must be visually inert, unfocused, have empty input masks and close any active transition.
Likewise, switching to Connected closes any detached Classic popup before activating the connected
owners. The selected style keeps the existing 44-pixel bar height and screen policy.

## Connected Notch style

### Existing application menus

Active Window and Input Method retain the current `EdgeMenuWindow`, `EdgeMenuSurface`,
`RightPillCoordinator`, `EdgeMenuGeometry` and `AnchoredMenuPillShape` architecture. Active Window
uses the left anchor and Input Method uses the right anchor.

### Connectivity notches

Wi-Fi, Bluetooth and Audio join that same right-side visual owner. Each control publishes a stable
screen-local anchor (`network`, `bluetooth`, `audio`). The selected anchor drives the existing
right branch geometry; the compact right pill stays visible and unrelated controls stay in place.

`SurfaceManager` remains the lifecycle and mutual-exclusion owner for these three features. Their
Connected descriptors identify the anchor and connected-Bar ownership. `EdgeMenuWindow` loads
the feature content for the active descriptor on its screen, while `OverlayHost` excludes that
descriptor so only one window paints and receives input.

The feature's Connected content component renders its existing Network, Bluetooth or Audio body
without a nested panel background, full-screen outside-click layer or independent entrance/exit
animation. The outer right-pill owner supplies silhouette, clipping, focus, outside-click and
reversible motion.

Branch geometry continues to use `EdgeMenuGeometry.branchRect`: y=28, 8 pixels of overlap with the
36-pixel compact pill, width bounded to 240–520 pixels, height content-adaptive and capped at 440
pixels, and a 12-pixel output margin. Open uses the existing 240 ms damped transition and close
uses the reversible 190 ms transition; Reduced Motion commits immediately.

### Connected component names

New feature popup bodies use explicit Connected names such as:

- `ConnectedNetworkPopupContent`;
- `ConnectedBluetoothPopupContent`;
- `ConnectedAudioPopupContent`.

The current detached popup filenames are not silently repurposed as Connected implementations,
because they remain the basis of the Classic mode.

## Classic Separate Pills style

### Top Bar layout

Classic restores the visual composition of `0cb73ec` under `Classic*` names:

- left: separate Arch button, Workspace pill and Active Window pill;
- true center: separate Center pill;
- near center: separate Notification pill;
- right: separate Pin pill, Connectivity pill and Input Method/status pill.

Spacing, padding, radii and individual `Shared.Surface` backgrounds follow the checkpoint while
using current semantic theme tokens. Classic hitboxes are composed into the `BarSurface` input
mask; transparent gaps stay click-through.

### Detached popups

Classic Wi-Fi, Bluetooth and Audio coordinators continue to create `SurfaceManager` descriptors
for `OverlayHost`, selecting newly named restored surfaces:

- `ClassicNetworkPopupSurface`;
- `ClassicBluetoothPopupSurface`;
- `ClassicAudioPopupSurface`.

These surfaces retain the checkpoint's detached panel geometry, independent background,
right-edge anchoring, outside-click layer, Escape handling, focus return and entrance/exit motion.
Their content uses the current services and current leaf rows so device and state behavior does
not regress.

Classic Active Window and Input Method use the detached popup behavior present at the checkpoint.
Where the old app-menu implementation no longer matches the current System Tray service contract,
the Classic adapter consumes the current projected menu values but preserves detached-window
geometry and lifecycle.

## Routing and style changes

Public coordinator and IPC entry points remain stable. Each feature coordinator reads the
effective Top Bar style and chooses one descriptor:

- Connected selects the right/left connected owner and Connected content;
- Classic selects `OverlayHost` and the matching Classic surface.

The choice is centralized in coordinators or a pure routing helper; controls do not duplicate
style conditionals. A style change first closes the current owner, clears keyboard focus and waits
for lifecycle cleanup before exposing the other tree. No popup is migrated while open.

Rapid style changes converge on the latest effective preference. A stale close callback checks its
owner ID/generation before clearing state, preventing it from closing a newer popup.

## Boundaries

- Services remain the sole native Network, Bluetooth, Audio and System Tray owners.
- Bar and popup views consume immutable service projections and narrow intents only.
- `SurfaceManager` remains the single transient-surface mutual-exclusion authority.
- Screen eligibility remains `ScreenPolicy.screens`; neither style paints on an ineligible output.
- No Hyprland configuration, external application launch, clipboard content or real device state
  is changed by automated verification.
- Classic restoration does not reinstate retired service ownership, polling or obsolete native
  object access from the old revision.

## Accessibility and failure handling

Both styles preserve current accessible names, roles, heading structure and keyboard traversal.
Exclusive focus exists only while the selected style owns an open popup. Escape and outside click
close the selected popup and return focus to its invoker when available.

Missing screen/source/anchor data fails closed. A Connected Loader error closes its matching
SurfaceManager owner and reverses the notch. A Classic Loader error closes the detached surface.
Unavailable feature data retains the existing unavailable presentation. Switching style while a
screen disappears clears both visual paths without falling back to another output.

## Settings migration

The settings schema/version migration adds `modules.bar.style` without changing unrelated values.
Fixtures cover:

- shipped defaults;
- upgrade from the current runtime schema with no style key;
- explicit `classic` and `connected` values;
- malformed and unknown values normalizing to `connected`;
- preview, Cancel and Apply behavior.

The existing Settings transaction remains authoritative; no separate Top Bar configuration file
is introduced.

## Verification

Test-first pure/static contracts cover:

- normalization and migration of `modules.bar.style`;
- central routing for Connected versus Classic descriptors;
- exclusive composition/input ownership for the selected style;
- three stable Connected anchor names and correct branch clamping;
- Classic component names and restoration source boundaries;
- no nested background in Connected content;
- detached background and OverlayHost ownership in Classic surfaces;
- external close, style switch and rapid reversal settling to one owner;
- no mutation of service or IPC contracts.

Run focused checks for Preferences, Settings, Bar, right-pill geometry, Network, Bluetooth and
Audio, followed by:

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/settings_acceptance.sh
./scripts/audio_acceptance.sh
./scripts/bluetooth_acceptance.sh
./scripts/wifi_acceptance.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
```

Live acceptance uses only existing read-only lifecycle IPC and does not toggle real radios,
connect devices or change volume. Manual review on DP-1 at scales 1.0 and 1.5 covers both styles,
every popup, style switching with a popup open, click-through gaps, Escape/outside-click, direct
switching between controls and absence of seams or duplicate layers.

## Non-goals

- Per-control style or visibility settings.
- Mixing Connected and Classic visual elements in one active Top Bar.
- Redesigning Network, Bluetooth or Audio content and behavior.
- Restoring obsolete services or old persistence formats wholesale.
- Applying notch ownership to unrelated overlays.
