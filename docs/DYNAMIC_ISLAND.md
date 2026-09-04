# Dynamic Island system and interaction specification

Status: canonical. This document supersedes every earlier Center pill/notch layout, navigation,
notification-satellite, shoulder/filler and expanded Overview specification where they conflict.
In particular, the Center designs and plans dated 2026-08-26 through 2026-08-31 are historical.

## State machine

| State | Geometry | Content | Entry |
| --- | --- | --- | --- |
| `compact` | Standard: 180–260 × 36dp; Ultrawide: 180–340 × 42dp | Daily Focus as the primary content | No active background activity |
| `satellite` | One content-sized segmented pill; standard ceiling 320dp, Ultrawide 340dp | Daily Focus plus one nested activity chip | At least one active background activity |
| `banner` | 480 × 72, R22 | Music, notification, or generic activity context | Primary/bubble click; urgent notification |
| `expanded` | 720 × 440, R28 | AI approval or clean extension canvas | AI request; Banner expand/media area; downward drag; global shortcut |

Daily Focus is the highest-priority non-blocking Primary content while Focus mode is enabled.
Its State 3 icon toggles the session mode between `center_focus_strong` and `center_focus_weak`.
When Focus is disabled, Media is promoted to Primary; if Media is absent, the highest-ranked live
activity becomes Primary. `CenterActivityService.activities` is the persistent activity source
for the nested Satellite segment; its existing order is authoritative and index 0 becomes
Secondary. Later entries never create more segments. This keeps Music in the nested chip while
Focus remains readable.
A current notification temporarily takes precedence in the nested chip and uses the wobbling bell
with a green acknowledgement tick; after its bounded presentation expires, the chip returns to the
highest-ranked live activity or disappears. Unread count alone does not keep a nested segment alive.

All dimensions are logical pixels (dp); Qt/Wayland applies the output scale when allocating physical
pixels. A standard display uses a 36dp height and 260dp primary ceiling. An Ultrawide display,
identified from its logical aspect ratio (`width / height >= 2.1`) so fractional scaling cannot
misclassify a 16:9 4K panel, uses a 42dp height and 340dp ceiling.

In Satellite, the complete visible silhouette remains one centered connected shape. The standard
ceiling grows to 320dp and the Ultrawide ceiling remains 340dp. The Primary text reserves 44dp at
the trailing edge: a natural 12dp separation plus a fixed 32×28dp nested capsule. There is no hard
divider and no detached bubble. Primary and nested regions own independent hover and click targets.
The cached secondary descriptor remains mounted until the chip's exit opacity/scale transition
finishes, then the outer pill contracts to its Compact width.

`CenterNotchCoordinator` publishes `visualState`, `selectedContext`, `primaryContext`,
`secondaryContext`, and `dragProgress`, with intents `openBanner`, `openExpanded`, `collapse`,
`selectActivity`, `setDragProgress`, and `finishDrag`. The stable states are exactly `compact`,
`satellite`, `banner`, and `expanded`.

## Ownership and rendering

Each eligible screen owns one always-mounted `CenterPillWindow`. It is the visual and input owner
in all four states. `CenterNotchSurface` contains exactly one `ConnectedPillShape` for the main
body and its two concave shoulders. The surface is opaque white/black according to theme; there
are no independent shoulder, filler, seam, `RoundCorner`, or surface cross-fades.

The owner layer spans only the eligible screen to support outside-click dismissal. Compact and
Satellite restrict its input mask to the visible cluster, and the transparent root adds no
full-screen painted item. Keeping this layer geometry stable avoids Wayland surface reconfiguration
during every morph frame; only the connected shape's scene-graph geometry is animated.

The same geometry values drive silhouette, content bounds, and input mask. Only content opacity
may cross-fade. Compact/satellite follows Bar reveal state. Banner/expanded forces the Bar open
until collapse.

## Content

Compact keeps source identity on the left and its live visualization on the right: notification
wobble and green tick, three-bar media equalizer, recording aura/timer, amber AI beacon, or the
idle Titonium mascot.

Banner scaffolds two first-class contexts:

- Music: artwork, title/artist, previous, play/pause, next, and progress.
- Notification: short summary/body. High urgency may auto-open it for four seconds.

AI approval bypasses Banner and opens Expanded directly, regardless of the current Center state.
Expanded gives approval priority over its clean canvas and embeds the complete normalized request,
queue position, Deny, native-review, Allow-for-session and Allow-once actions. Resolving a request
keeps Expanded open for the next queued approval; resolving the final request collapses the owner.
High-urgency notification auto-entry remains limited to compact/satellite, and Music never
auto-opens. Legacy Overview and Notification Center pages are not restored.

## Input and transitions

- Primary click opens its Banner. In Satellite, clicking the nested chip opens secondary context.
- Banner expand control or designated media body opens Expanded.
- Dragging the Banner lower edge updates `dragProgress` continuously. Release at 48 px or a
  downward velocity of 500 px/s settles to Expanded; otherwise it settles back to Banner. The
  90–180ms settle starts at the release progress, so neither branch snaps to 0 or 1.
- Right click on the compact body opens Settings at page `bar`.
- Escape or outside click collapses Banner to compact/satellite based on current activities;
  Expanded always collapses directly to the compact owner before activity-derived layout settles.
- The compositor-facing shortcut is `titonium:dynamicIsland`. To bind Super+I in Hyprland, add
  `bind = SUPER, I, global, titonium:dynamicIsland` to user compositor configuration. Titonium does
  not modify protected Hyprland files.

Compatibility IPC remains `qs ipc call centerNotch open banner|overview`: `overview` maps to
Expanded. `centerNotch state` includes both stable `state` and selected `context`.

## Motion and acceptance

Geometry opens in 220–250 ms and closes in 180–200 ms using the shared damped spring curve, with
overshoot capped around 1.05. Transitions may reverse immediately; the owner and hitbox never
disappear between states. Reduced Motion sets geometry/content durations to zero. No hidden
component owns an infinite animation.

Compact and open content remain mounted during geometry motion and use the same reversible
`transitionProgress`. Compact fades during the first 35% of opening; contextual content begins
after 15% and reaches full opacity by 65%. The inverse curve is used on close, preventing either
content tree from appearing abruptly or stretching to the other state's dimensions. Banner and
Canvas similarly cross-fade through `canvasContentProgress`, including interactive drag progress.

Content components never animate `implicitWidth` or `implicitHeight`. A presentation change
publishes one clamped compact-width target through `setCompactWidth`; only the screen-local visual
owner animates geometry. This prevents per-frame Coordinator writes and nested animation
retargeting while the connected path is being tessellated.

Pure tests cover state derivation, top-two ranking, auto-open policy, drag thresholds and fallback.
Static tests enforce one window owner, one connected main shape, the geometry/radius constants,
one-shot notification timeout, and removal of legacy CenterGroup/NotificationPill owners. Runtime
acceptance covers the full state loop, both satellite targets, drag success/cancel, AI persistence,
notification timeout, Settings/Spotlight exclusion, input masks, and scale 1.0/1.5.
