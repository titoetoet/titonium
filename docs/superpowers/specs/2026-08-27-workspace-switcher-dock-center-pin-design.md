# Workspace, Switcher, Dock, and Center Pin Design

## Goal

Complete one interaction-focused Titonium batch on DP-1:

- make Window Switcher acceptance move to the selected window's workspace;
- replace the temporary workspace strip with a five-slot, grouped workspace view adapted from
  Ambxst's useful presentation patterns;
- separate the Dock pin from the launcher hit area and remove Dock hover text;
- add a Center pin control to the TopBar, immediately to the right of the Center island.

Bluetooth is explicitly outside this batch. Titonium must not add reconnect behavior, mutate a
Bluetooth device, restart WirePlumber, or change the current Bluetooth/audio handoff while the user
tests whether the reference DankMaterialShell caused the observed disconnects.

## Constraints

- Titonium continues to own only `DP-1`; `DP-3` remains available to the reference shell.
- The protected Spotlight, Input Method, screen lifecycle, keybindings, and lazy overlay lifecycle
  retain their existing behavior.
- UI files contain no `Process`, raw `hyprctl`, persistence, polling timer, or native Hyprland
  object.
- One `HyprlandService` remains the sole owner of native workspace and toplevel observation.
- The implementation adapts behavior, not Ambxst's Axctl/Go backend, theme system, global config,
  raw view objects, or debounce timer.
- Automated tests do not launch real applications or mutate Bluetooth, audio, clipboard, or
  Hyprland configuration files.

## Shared Hyprland window contract

`HyprlandService.windows` remains a list of immutable public descriptors. Each descriptor gains:

- `workspaceId`: positive Hyprland workspace ID, or `0` when unavailable;
- `monitorName`: output name, or an empty string when unavailable.

The service continues to re-resolve a raw native toplevel immediately before an action. A single
public focus method owns cross-workspace activation: resolve the descriptor, activate its native
workspace when it differs from the active workspace, then activate the window. Stale or incomplete
descriptors fail safely without exposing the raw object to Dock, Window Switcher, or workspace UI.

Both Window Switcher acceptance and Dock running-app activation use this shared method. This avoids
two subtly different focus flows and makes clicking a Dock app on another workspace behave like
accepting it from the switcher.

## Window Switcher release behavior

The existing Super+Tab bindings and presentation remain unchanged. Releasing Super accepts the
current selection through `WindowSwitcherService.accept()`; the service closes the switcher first,
then invokes the shared workspace-aware focus method.

The action sequence is:

1. capture the selected public window ID;
2. close and clear the switcher state;
3. re-resolve the native toplevel in `HyprlandService`;
4. activate its workspace when necessary;
5. activate the window, deferring only the final window activation to the next Qt event turn if
   Hyprland requires the workspace transition to settle.

An empty selection or a window that disappeared during the switch is a no-op and never leaves the
overlay open.

## Five-slot grouped workspace view

The workspace view always renders the current group of five IDs. Group boundaries remain
`1–5`, `6–10`, and so on, derived from the active workspace. It does not grow with the number of
open workspaces.

The view adapts four Ambxst ideas:

- adjacent occupied workspaces share a subtle contiguous backing segment;
- the active highlight stretches between previous and current positions during navigation, then
  settles to one slot;
- the active slot may show the most recently focused app icon for that workspace;
- wheel input navigates to the previous or next workspace while click activates an exact slot.

The service projection, not the view, determines occupancy, urgency, and the active workspace app.
The existing MRU-ordered public window descriptors provide the first icon on each workspace. A
missing icon falls back to the workspace number. Inactive occupied slots retain a small semantic
indicator; empty inactive slots remain lightweight. The bar remains 40 logical pixels high and no
continuous animation or polling is introduced.

## Dock pin geometry and hover behavior

The Dock surface keeps its current icon size, auto-hide behavior, pinned reservation, launcher
action, application actions, and context menu. Only the pin geometry and hover text change.

The panel body is inset slightly inside the existing 64-pixel Dock window. The pin uses a small
pointer hitbox that overlaps the panel's upper-left border, outside the launcher's hitbox. Its
visual glyph is smaller than its hitbox and appears only while the Dock surface is hovered. The
surface input mask includes the pin hitbox explicitly, and the pin remains pointer-only with no
keyboard focus. Toggling it must not leave exclusive keyboard focus or steal typing from another
window.

All application hover tooltips and hover text are removed. Application names remain available in
the existing context menu and accessibility metadata; removing visual hover text must not remove
accessible names.

## TopBar Center pin

The Center group becomes a compact horizontal composition: the existing Center island followed by
a separate pin button on its right. The group as a whole remains geometrically centered on the
screen, and the Bar input mask covers both controls while preserving click-through elsewhere.

The Center pin controls the existing Center Notch lifecycle:

- activating the pin opens the current/default Center page if needed and marks the notch pinned;
- while pinned, outside clicks do not close the Center Notch;
- Escape, Spotlight opening, focused-monitor loss, explicit close, or pressing the pin again closes
  it and clears the pinned state;
- pin state is session-only and is not written to runtime settings;
- only the active owner screen can show an active pin state.

This is intentionally separate from the Dock's persistence-backed pin. No shared generic pin
store or cross-feature dependency is introduced.

## Error handling and lifecycle

- Unknown workspace IDs and missing native windows are logged at most once per action category and
  resolve to safe no-ops.
- A monitor change closes the switcher and any unowned Center Notch state through existing
  coordinators.
- Center pin state is reset whenever the Center Notch owner is cleared, preventing an invisible
  pinned state.
- Dock pin input bounds are deterministic and do not overlap the launcher bounds.
- Bluetooth source and runtime state are not touched.

## Verification

### Automated RED/GREEN contracts

- Window descriptor rules test `workspaceId`/`monitorName`, stale data, and workspace-first focus
  routing.
- Window Switcher architecture tests require the shared focus boundary and close-before-focus
  acceptance.
- Workspace pure rules test five-slot grouping, occupied ranges, MRU icon selection, and empty
  fallback behavior.
- Bar contracts require exactly five slots, click/wheel intent, bounded animations, and the Center
  pin's right-of-island composition/lifecycle.
- Dock layout contracts require disjoint pin/launcher hit regions, no tooltip presentation, an
  explicit pin mask, and pointer-only focus semantics.
- The full static gate and `git diff --check` pass.

### DP-1 live acceptance

- Super+Tab cycles; releasing Super closes the switcher and shows the selected window on its own
  workspace.
- The workspace strip shows five grouped slots, correct occupied ranges and active app icon;
  click and wheel navigation work without bar jitter.
- Dock pin appears only on hover, sits over the border, never activates Launcher accidentally, and
  typing remains in the previously focused application after repeated pin/unpin cycles.
- Dock apps show no hover tooltip.
- The TopBar pin sits immediately right of Center, opens/persists the Center Notch across outside
  clicks, and Escape/Spotlight/unpin clears it.
- DP-3 has no Titonium layer; protected Spotlight and Input Method acceptance still pass;
  `hyprctl configerrors` is empty.
- No automated or manual step in this batch changes Bluetooth state.

## Provenance

Workspace presentation patterns were reviewed from the local Ambxst checkout at
`/home/cole/Projects/Ambxst`, especially
`modules/bar/workspaces/Workspaces.qml`, `modules/bar/workspaces/CompositorData.qml`, and
`config/defaults/workspaces.js`. The implementation will be rewritten behind Titonium contracts;
no Ambxst service, backend, theme, or raw compositor object is imported.
