# Theme baseline

The skeleton uses a static **Neutral Utility** token layer:

- `Theme/Theme.qml`: semantic light/dark colors;
- `Theme/Typography.qml`: SF Pro Display with Noto Sans fallback;
- `Theme/Metrics.qml`: 4/8 logical-pixel grid, 44dp bar, 36dp controls and small radii;
- `Theme/Motion.qml`: short durations with reduced-motion collapse;
- `Shared/*`: thin controls that consume only semantic tokens.

## Pill and surface primitives

`Shared.Surface` supports per-corner radii and an optional `customColor`. Feature views use the
semantic `tone` path by default; `customColor` is reserved for deliberate silhouettes.
`Shared.ConnectedPillShape` draws the Center body, both concave shoulders and their connection as
one closed `ShapePath`. There are no independent shoulder or filler items, so antialiasing cannot
expose seams between pieces. The shape is presentation-only and owns no input or feature state.

The left and right Bar regions use `Shared.EdgePillShape`. Each shape is flush with the screen's
top and outer edge, keeps that outer edge square, and draws one concave shoulder facing the center.
Launcher, workspace, active-window, pin, connectivity and status children must not add their own
resting card backgrounds. Hover and pressed feedback may remain local to a control, while each
side's base silhouette stays continuous.

Right-pill controls use uniform 28dp interaction cells. Connectivity icons have 4dp internal gaps
and the Pin, Connectivity, Input Method and conditional Notification groups have 8dp gaps. The Pin
has no resting, hover or selected background; state is communicated through its glyph and color.
The Notification bell occupies no layout width without unread items and runs only three wobble
cycles when the unread count increases.

Both edge pills animate their displayed width toward the latest content-derived implicit width in
220ms with `Motion.springDamped`. Rapid Window Title or unread changes retarget the same animation
instead of queuing transitions. The left pill remains fixed to the left edge and the right pill to
the right edge; content stays edge-anchored and clipped while the chassis catches up. Reduced Motion
applies the target width immediately.

The Center compact pill uses a 36dp standard or 42dp Ultrawide height, with bottom/shoulder radii
equal to half that height. The screen-local visual owner
morphs that same silhouette to the 480×72 banner or 720×440 expanded canvas. Closing reverses the
geometry without releasing the owner. The background stays fully opaque throughout; compact and
open content cross-fade from one reversible `transitionProgress` instead of switching visibility at
the state boundary.

Width tokens describe the complete visible connected silhouette. The `ShapePath` body width is
derived by subtracting both shoulders (`visualWidth - 2 × shoulderSize`), preventing the connected
path from exceeding its profile-specific 260dp or 340dp visual-width ceiling.

## Motion contract

Edge application menus use the same continuous-chassis rule: the horizontal pill remains stationary
and fully visible while one branch grows from the clicked control down through the Top Bar. A single
path draws that union. The branch reaches a 420dp adaptive canvas without being forced against the
screen edge. Open/close durations are 240ms/190ms with `Motion.springDamped`; only the branch geometry,
menu opacity and a small reveal translation change. The opposite edge receives zero branch progress.
For a Left Pill application menu, the branch right edge is the direct vertical continuation of the
pill's inner shoulder. Width is reduced before that alignment is sacrificed.

`Motion.springDamped` is the shared damped Bezier curve for surface entrance and geometry morphs.
Center uses a 240ms width/height expansion, 220ms radius transition and 190ms collapse. Compact
content fades over the opening's first 35%; open content enters from 15% through 65%, and the same
curves reverse on close. A transition can reverse immediately when
the user clicks during collapse. Approval cards, transient popups, Settings,
Window Switcher and Spotlight use short opacity/scale/translation entrances built from the same
tokens. Top Bar controls keep their chassis and text stationary: only the hovered icon lifts 1dp
and scales to 1.08, then compresses to 0.96 while pressed. Center Compact content cross-fades
without scale during an open or close transition. All continuous or entrance motion must stop or
collapse immediately when `Motion.reduced` is true; hidden components must not keep animating.

Workspace capsules share a fixed 24dp height and neutral inactive color. A single blue selection
highlight owns active state: its leading edge first stretches across the distance between the old
and new workspace, then its trailing edge settles to the target width. Workspace delegates and app
icons never resize as part of this selection transition.

Only renderers below `Bar/center/presentations` own Center width, height, radius, and content
animation. They receive immutable semantic and view state and report transition completion with
the supplied generation; they do not synchronize business state during animation frames.

It is solid, opaque and compositor-independent. There is no theme catalog, material resolver,
glass backend, shader, blur or `hyprland.lua` synchronization in the current runtime.

Center's Pill, Notch, Connected, and Classic profiles are presentation choices over one semantic
snapshot and one controller state. Profiles may select geometry, radii, transitions, and supported
layout affordances. They must not import source services, select business priority, own timeouts,
change screen ownership, or execute actions. Switching the Top Bar style passes a new immutable
profile to the existing `CenterSurfaceHost`; it does not recreate the Center domain or controller.

Future repository research may evaluate matugen or a simple `colors.json` input. The accepted
design must keep semantic token names stable, load data once, validate/fallback safely and avoid
forcing any functional module to import a theme provider directly.

Hybrid glass remains a possible future appearance module, not a skeleton capability. If revived,
hyprglass must be treated as optional and version-sensitive, with a solid fallback and zero source
mutation or automatic compositor reload. Theme work never reads, edits or reloads either Hyprland
configuration file.
