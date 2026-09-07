# Theme baseline

The shell exposes a stable semantic token facade, resolved by `Services/Appearance`:

- `Theme/Theme.qml`: semantic colors and material tokens; `AppearanceService` resolves Neutral, Glass, Soft and Graphite in Light/Dark/System;
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

The Connected left and right Bar regions use `Shared.AnchoredMenuPillShape` in
`Bar/right/EdgeMenuSurface.qml`. Each shape owns the continuous edge pill and its expanding menu
branch. The retired `EdgePillShape` component was removed during the source cleanup.
Launcher, workspace, active-window, pin, connectivity and status children must not add their own
resting card backgrounds. Hover and pressed feedback may remain local to a control, while each
side's base silhouette stays continuous.

Right-pill controls use uniform 28dp interaction cells. Connectivity icons have 4dp internal gaps
and the Pin, Connectivity, Input Method and Notification Center groups have 8dp gaps. The Pin has no
resting, hover or selected background; state is communicated through its glyph and color. The
rightmost Notification Center control is always present in both Bar styles and retains its fixed
non-bell `history` glyph; only its unread badge is conditional. It never wobbles.

The non-interactive Center secondary compact pill is the only notification bell presentation. It
sits outside the primary Center pill with an 8dp gap and its own four rounded corners. When unread
count increases it may run at most three wobble cycles; Reduced Motion suppresses that motion without
changing the unread presentation. This is a compact presentation detail, not a satellite lifecycle
mode, and it does not redesign or change the behavior of the current primary pill.

Both edge pills animate their displayed width toward the latest content-derived implicit width in
220ms with `Motion.springDamped`. Rapid Window Title or unread changes retarget the same animation
instead of queuing transitions. The left pill remains fixed to the left edge and the right pill to
the right edge; content stays edge-anchored and clipped while the chassis catches up. Reduced Motion
applies the target width immediately.

The Center compact pill uses a 36dp standard or 42dp Ultrawide height, with bottom/shoulder radii
equal to half that height. Connected morphs that same silhouette to the 480×72 banner or 720×440
expanded canvas. Classic keeps the compact pill unchanged and presents both banner and expanded as
detached, top-centered `Shared.Panel` popups at `Metrics.barHeight + Metrics.barSpacing`, using
`Theme.surface`, the shared outline and panel padding. Critical notification banners use this same
Classic popup path.

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
Connected Center uses a 240ms width/height expansion, 220ms radius transition and 190ms collapse. Compact
content fades over the opening's first 35%; open content enters from 15% through 65%, and the same
curves reverse on close. A transition can reverse immediately when
the user clicks during collapse. Classic Center uses the detached-popup language shared with its
Wi-Fi and Bluetooth panels: open opacity 150ms plus 220ms `0.94 → 1` scale and `-12 → 0`
translation; close opacity 120ms plus 130ms `1 → 0.96` scale and `0 → -8` translation. Approval
cards, other transient popups, Settings,
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

Neutral preserves the opaque baseline. The other presets use compositor-independent QML paint: background alpha, gradient sheen, bounded outline and primitive shadow. There is no backdrop blur, shader, hyprglass backend or `hyprland.lua` synchronization.

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


## Appearance Settings and Advanced (2026-09-06)

Appearance selection is local until **Try for 15 seconds** or **Apply**. Keep a trial stages it in the existing Settings transaction; only Apply persists. Basic mode and theme are independent of Connected/Classic bar and dock layouts. Settings v8 migration preserves existing v6/v7 mode, bar, mascot and Dock state under the Neutral preset.

Advanced is lazy and stores custom values per theme and Light/Dark variant. It offers accent, background opacity (85–100%), border/shadow/sheen strength, ordinary surface radius (75–125%), motion speed (50–150%) and Reduced Motion. Closing Advanced retains custom values. While System mode changes, Advanced keeps its editing variant fixed and labels it. Reduced Motion uses the existing accessibility field and takes precedence over animation timing.

`AppearanceCoordinator` owns candidate, timed runtime trial and one successful-Apply undo record. `Preferences` remains the only settings writer. Candidate normalization precedes wallpaper journaling, so durable journal and persisted preferences compare the same representation. Closing/losing the Settings screen during asynchronous work requests cancellation and releases the preview after the pending operation completes. A post-save wallpaper-finalization failure offers retry; Cancel never rolls back an already committed wallpaper behind the saved preference.

Wallpaper preview shares `WallpapersService` with Center. Its lease prevents Center Apply from racing a trial. The service writes a recovery journal outside Git, probes actual baseline capability, and supports committed custom/preset wallpaper following on DP-1. Hyprpaper v0.8.4 rejects `get-active`, so explicitly enabled managed mode applies a known baseline and tracks subsequent acknowledged changes against the daemon session. New-session recovery re-establishes the saved managed path before following the committed theme/custom policy. Pending trial recovery takes precedence. See `Titonium/Services/Wallpapers/README.md` for initialization and the limitation on external wallpaper changes. Keeping the current wallpaper leaves theme and Advanced controls available without managed mode. Automated tests use private fake sockets, never change the user's wallpaper.

Original wallpapers live under `Theme/assets/wallpapers` with CC0 provenance. No third-party theme engine or wallpaper assets were copied.


### Hyprpaper 0.8.4 managed baseline

The explicit `appearance-initialize` backend action accepts `{screen:"DP-1", path:"/absolute/local/image.jpg", fit:"cover"}`. It applies that image and fit before enabling managed mode. It never infers the active wallpaper from `hyprpaper.conf` and never changes DP-3, starts a daemon or edits compositor configuration. Initialization refuses while a trial journal exists.

Runtime files are under `$XDG_STATE_HOME/titonium/wallpapers` (default `~/.local/state/titonium/wallpapers`): `managed-policy.json` stores the opt-in and last committed managed image/fit; `managed-current.json` stores the last acknowledged wallpaper and its daemon identity. Identity includes the compositor instance, socket path/device/inode/creation timestamp and Linux boot ID. Capture trusts this tracker only for the matching identity. All Titonium DP-1 mutations invalidate the tracker before IPC and update it only after acknowledgement against the same identity. Trial applies update the tracker but never the committed managed policy; Center Apply and appearance commit update that policy. Timeout or ambiguous failure leaves no trusted tracker.

On login or daemon replacement, recovery first resolves any appearance journal. It then re-applies the committed managed image if the session tracker is absent or invalid, establishing an observed baseline before normal committed-theme following. Without managed opt-in, recovery never performs this initialization. A read-only capability probe never re-applies anything. If the daemon has not started, recovery returns `managed:true` and unavailable capability so the service can retry on its bounded startup/event schedule.

Hyprpaper 0.8.4 does not expose active state, so out-of-band `hyprctl hyprpaper wallpaper` writes cannot be detected within the same daemon session. Managed baseline mode assumes wallpaper changes go through Titonium. After an external wallpaper command, explicitly initialize with the desired known image again before relying on trial rollback. The normal configuration may still start Hyprpaper; managed initialization is an explicit user-authorized action, not a guessed config baseline.

Image validation retains the 32 MiB encoded-file and 40 million pixel limits. The decoder uses a 512 MiB memory ceiling, no memory map or disk cache, one thread and a five-second decode timeout. The previous 128 MiB ceiling rejected valid large JPEGs below the pixel limit; a 6966×4672 generated JPEG regression now verifies bounded full decoding.
