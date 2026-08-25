# Testing

## Static checks

`scripts/check.sh` performs JSON validation, lunar conversion fixtures, architecture policy
checks and `qmllint`.
Quickshell-specific lint warnings may be narrowly allowlisted in
`scripts/qmllint_allowlist.txt` with an adjacent explanation. Quickshell 0.3.1 currently
marks `PanelWindow` uncreatable in lint metadata even though it is the documented runtime
layer-shell window type, so the foreground smoke test covers that narrow exception. Errors,
missing members and duplicate IDs are never allowlisted.

## Runtime smoke test

`scripts/smoke.sh` starts the project in the foreground for a bounded interval, captures the
log and fails on QML errors, type errors, duplicate IDs or missing members. It must observe
`Configuration Loaded`.

`scripts/runtime_acceptance.sh` temporarily installs isolated runtime-layout fixtures,
verifies invalid data falls back and unknown widget types render through the diagnostic
component, then restores the previous runtime layout exactly.

`scripts/settings_acceptance.sh` backs up both runtime documents, exercises Preview, Cancel,
Apply, Restore Appearance and hybrid backend resolution through live IPC, verifies repository
state plus both `hyprland.lua` hashes, and restores the original runtime files on every exit path.

Theme acceptance additionally verifies the settings v1→v2 migration, appearance-only restore,
Neutral Utility solid policy, hybrid `auto/native → qml` fallback, Gallery open/close IPC and unchanged hashes for both Hyprland
configuration copies. Gallery content must disappear from the scene when its Loader is inactive.

## Manual acceptance

- One MenuBar appears on DP-1 and DP-3.
- Each output reserves exactly 40 logical pixels at the top.
- Labels remain readable at scale 1.0 and 1.5.
- Invalid runtime configuration falls back to defaults.
- An unknown registry type renders a diagnostic item without crashing.
- Applying settings does not modify the repository.
- `hyprctl configerrors` is empty.
- Neutral Utility resolves to `solid` in both dark and light previews.
- Restore returns to dark while preserving locale, accessibility, modules and layout.
- Gallery opens only on its requested screen and closes without leaving preview state active.
- Typography variants remain legible in dark/light mode and at output scales 1.0/1.5.
- Icon glyphs resolve through Material Symbols without image or filesystem fallback.
- Button variants support pointer activation, Tab focus and Enter/Space activation; disabled
  buttons cannot emit actions.
- Surface/Card/Panel remain opaque under Neutral Utility and never allocate an effect layer.
- Interactive Card responds to pointer and keyboard while non-interactive containers remain
  passive. Nested Card content stays inside Panel padding at both target output scales.
- Switch toggles with pointer/Space/Enter; Slider clamps and snaps pointer/arrow/Home/End input;
  disabled controls cannot mutate state.
- Dropdown option content is absent while collapsed, supports arrow/Enter/Escape navigation and
  emits the selected index/value without persistence or platform access.
- Tabs form one Tab stop, wrap with arrow keys, support Home/End, and expose page-tab-list/page-tab
  roles with a selected state. Focus must remain visible in dark/light mode and at both scales.
- Disabled controls stay outside the keyboard focus chain; Dropdown closes when focus leaves it.
- Gallery requests exclusive keyboard focus only while open; Escape cancels preview and releases
  the layer-shell focus immediately.
- Workspaces always renders its configured cell count, marks active/occupied state per screen and
  activates both existing and empty numeric workspaces through the Platform adapter.
- Active Window updates its elided title on focus changes and falls back to Desktop when no
  toplevel is active; DP-1 may use a wider screen override without changing DP-3.
- Input Method follows Fcitx StatusNotifier changes (`Lotus → VI`, keyboard US → `EN`) without a
  process or timer and presents `IM` only when the service state is unavailable.
- Clock updates at minute precision without a timer/process. Calendar opens on the requested
  screen, supports previous/next/today, closes by outside click/Escape, and releases the heavy
  tree when closed. Lunar fixtures cover Tết 2024–2026 and Trung thu 2023.
- Launcher discovers only visible desktop entries, searches name/generic name/comment, filters
  category records and never creates more than 24 tiles. Pointer/Enter opens through
  `DesktopEntry.execute()`; Escape clears a query before closing the Dashboard.
- Settings preview updates every surface, but closing by any lifecycle path restores committed
  state. Apply writes only the atomic runtime settings/layout files. Theme metadata is resolved from a
  validated package; Typography font/size overrides reset independently of other appearance.
- Layout height/padding/spacing preview on both outputs and Cancel restores the exact document.
  Enabling Frame creates one click-through layer per output; disabling or cancelling removes all
  frame layers. Appearance, Layout and Frame reset actions must not modify each other's state.
- Audio, System and Launcher pages write only their owned settings subtree. The Audio visualizer
  controls store future preferences but never create an audio stream or animation in Settings.
  System exposes no power/session command, and Launcher preferences immediately affect catalog
  category, tile limit, columns, subtitles and search focus.
- Hybrid Glass `auto` resolves to native only when the one-shot Platform probe confirms hyprglass
  is loaded. Otherwise it resolves to QML without error. Selecting Neutral immediately removes
  the Material page and every surface resolves solid. QML glass uses no shader/effect/idle loop.
