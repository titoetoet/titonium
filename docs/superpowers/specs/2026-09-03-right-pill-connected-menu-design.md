# Right Pill Connected Menu Design

> **Superseding correction — control-anchored extrusion:** The edge-wide morph described below is
> superseded where it conflicts with this section. The Top Bar pill remains visible at its compact
> height. A menu is not aligned to the screen edge and does not replace the whole pill. Instead,
> one shape path draws the union of the existing horizontal pill and a downward branch originating
> at the clicked control: Active Window/ChatGPT inside the left pill, or Input Method inside the
> right pill. The branch overlaps the pill vertically, so there is no connector, filler, header,
> nested panel, seam or second background.

## Approved control-anchored geometry

- The horizontal pill retains its current screen-edge attachment, dimensions and content.
- Each compact presentation exposes the clicked control's local `x`, width and screen-space edge.
- The menu branch follows the larger of its projected menu content and dynamic source-pill content,
  including 16dp horizontal insets. Width remains bounded to 240–520dp; height is content-adaptive
  and capped at 440dp.
- Each menu stays centered on the clicked control (Window Title on the left or Input Method on the
  right) whenever space permits. It keeps the full usable width near an output edge and clamps to
  the 12dp output margin, preventing edge-adjacent Input Method menus from collapsing to nothing.
- While a menu opens, only the pill containing the clicked control resizes so its inner shoulder
  follows the menu's attached edge. If output clamping shifts the menu away from the original
  source centre, that source title/icon translates with the same progress to remain centred above
  the menu. The opposite pill, unrelated controls and the transparent gap remain unchanged.
- The branch begins at y=28dp and reaches below the 36dp compact pill, creating an 8dp overlap.
- One `AnchoredMenuPillShape` draws the complete union. It owns one `Shape` and one `ShapePath`.
- During open, the branch height and width interpolate from the source control bounds to the menu
  bounds. The horizontal pill never scales, moves or fades.
- Menu content clips to the branch rectangle and fades in only after usable height exists.
- The input mask is the compact pill plus the animated branch while opening/closing; when open, an
  outside-click layer additionally covers the output.
- Active Window routes with source `left`; Input Method routes with source `right`. The opposite
  pill remains unchanged. Opening either menu must not disable the compact controls on either
  edge; selecting another Top Bar control routes that intent directly and closes/replaces the
  current menu through the normal mutual-exclusion boundary.

## Goal

Replace the detached application DBusMenu popup with an edge-connected surface that morphs
directly out of the Top Bar pill containing the clicked control. The menu remains independent from Dynamic Island state,
but follows the same continuous chassis and reversible motion principles as the Center
State 3 → State 4 transition.

## Scope

- Apply the connected menu behavior to every app-associated DBusMenu exposed through
  `SystemTrayService`, not only ChatGPT.
- Route Active Window app menus through the left chassis and Input Method through the right chassis.
- Keep Wi-Fi, Bluetooth and Audio on their existing specialized popups because they are not
  DBusMenu consumers.
- Keep the Dynamic Island coordinator, state and content independent from the right menu.

## Visual ownership

One screen-local `EdgeMenuWindow` owns both edge silhouettes. `BarSurface` retains only their layout
reservations and must not paint duplicate edge backgrounds. Each edge has one
`AnchoredMenuPillShape`; only the selected control anchor receives branch transition progress.

The compact shape remains the existing top-and-outer-edge-attached pill with one inward-facing
concave shoulder. During expansion its horizontal outline remains unchanged while the same path
grows a branch downward from the clicked control. There is no independent connector, header,
filler, background card, nested panel or cross-faded surface.

## States and geometry

The coordinator has two stable states:

- `compact`: content-derived left/right pill widths and the current 36dp height.
- `menu`: a 420dp branch with content-derived height, clamped to the available output height and a
  440dp maximum.

All dimensions are logical pixels. The branch starts at y=28dp, overlaps the compact pill by 8dp,
and aligns with its clicked control rather than an output edge. Its content uses 16dp insets and
begins directly with menu entries; it has no app title, app icon or pill header. A Back row appears
only inside a submenu.

The path, clip, visible geometry and input region are derived from one transition progress. The
compact Bar reservation follows the latest compact target rather than the expanded menu width.

## Content transition

Compact pill content remains visible. Only the source title/icon follows a menu centre displaced
by output clamping; unrelated controls remain stationary. Menu entries fade in with a small
downward reveal only after sufficient branch height exists. Text and icons never scale as part of
this state transition.

The menu viewport scrolls when entries exceed the adaptive height. It preserves the existing
separator, disabled, checkbox, radio, icon and submenu presentations. Loading and empty states stay
inside the same chassis.

## Menu routing

`SystemTrayService` and its private backend remain the sole `QsMenuOpener` owner. A shared menu view
consumes only the projected `popupEntries`, navigation state and narrow service intents. No view
retains native menu objects.

Clicking an app-associated region follows one rule:

1. Resolve whether the app has a DBusMenu and preserve the source edge.
2. Prepare that menu through `SystemTrayService.prepareAppMenu`.
3. Open the matching left or right owner in `menu` state.
4. If no menu exists or preparation fails, preserve the caller's existing non-menu fallback.

Input Method uses `prepareInputMenu` and the same owner. Entering a submenu keeps the canvas open
and exposes Back. Triggering a normal app command closes the canvas after dispatch. Checkbox and
radio actions keep it open when the backing menu remains valid.

## Interaction and lifecycle

- Escape or an outside click reverses the morph to `compact`.
- A click during close immediately reverses toward `menu` without a dead input interval.
- If the selected menu or source disappears, close safely and reset popup navigation.
- Opening Spotlight or an expanded Center surface closes the right menu first.
- Opening the right menu closes other transient surfaces through the existing mutual-exclusion
  boundary.
- Compact interactions are disabled after the menu transition crosses its input handoff point;
  menu interactions become enabled only after that point.

## Motion

- Open: 240ms using `Motion.springDamped`.
- Close: 190ms using the same reversible progress.
- Content fade/translation is derived from progress and does not own another entrance animation.
- Reduced Motion commits geometry and content immediately.
- Hidden menu content and compact indicators run no continuous animation.

## Refactoring

Extract the reusable projected menu rows from `SystemTrayPopupSurface` into a presentation-only
`SystemTrayMenuView`. Retain `SystemTrayPopupSurface` only if a non-Bar consumer still requires it;
otherwise remove its coordinator, surface and registration after call-site verification. The new
right coordinator exposes only stable state, selected menu source, compact geometry and open,
close and toggle intents.

## Verification

Pure/static contracts verify:

- one right visual owner and one connected path;
- no header, nested panel, filler or duplicate right surface;
- app and Input Method menu routing through the shared service;
- correct 420×adaptive/440dp geometry;
- reversible timing and Reduced Motion behavior;
- no infinite animation while menu content is hidden.

Runtime acceptance covers compact → menu → compact, rapid reversal, submenu and Back, command,
checkbox/radio behavior, stale-menu disappearance, click-outside, Escape, mutual exclusion with
Spotlight and Center, input masks, and display scales 1.0 and 1.5.
