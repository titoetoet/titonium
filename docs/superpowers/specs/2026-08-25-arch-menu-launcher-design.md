# Arch Menu Launcher Design

**Date:** 2026-08-25  
**Status:** Approved in conversation; awaiting written-spec review

## Purpose

Replace the current Launcher dashboard with a left-anchored Arch Menu that is easier to
understand, extend and test. The Arch logo remains the only Launcher trigger and sits at the
left edge of the MenuBar, before Workspaces and Active Window.

Spotlight is outside this design. It keeps its legacy interaction flow, remains a separate
future module and is not opened or hosted by the Launcher. The Launcher has no keyboard
shortcut.

## User experience

Clicking the Arch logo opens a fixed-size popup below the left side of the MenuBar. Its
responsive maximum size matches the existing Settings Center (nominally 980 by 700 logical
pixels, constrained to the available screen). The popup does not resize when the selected
section changes.

The popup has two regions:

1. A narrow navigation rail on the left, approximately 64–72 logical pixels wide. It contains
   icons only, with accessible names, tooltips, keyboard focus and a selected state.
2. A content workspace filling the remaining width. Only the selected section is loaded.

The rail order is:

- Profile/avatar at the top.
- Apps.
- Places.
- Info.
- Settings.
- Flexible space.
- Power pinned at the bottom.

Apps is the default section. Controls is intentionally omitted. Sections that are not yet
implemented are not shown as non-functional placeholders.

## Apps section

Apps displays the complete application catalog in alphabetical order. It has no search field,
favorites, recent-app section, usage ranking or category tabs.

The grid is adaptive rather than fixed to six columns. It derives the column count from the
available content width and a semantic minimum tile width. It then derives rows from the
available height and semantic tile height. Page capacity is `columns * rows` and is recalculated
when screen scale, density or popup constraints change.

Application names occupy one line and use width-based elision. There is no manual character
limit. Vertical wheel input changes horizontal pages. Existing reduced-motion and Launcher
transition settings continue to govern page animation. The existing page indicator remains and
reflects the number and relative fullness of every page.

Launching an app closes the Arch Menu. An invalid desktop entry is ignored, logged through the
application adapter and does not close or crash the shell.

## Places section

Places is a native QML file navigator inspired by Yazi; it does not embed a terminal client or
run Yazi. Its initial version is read-only and supports navigation, preview and opening files.
Copy, move, rename, create and delete operations are explicitly deferred.

The content uses three columns:

- Bookmarks and available locations: Home, Projects, Downloads, Documents and mounted drives.
- Entries in the current directory.
- A preview or metadata pane for the selected entry.

Keyboard navigation may include arrows, Enter, Backspace and Yazi-like `h`, `j`, `k`, `l`
bindings when they do not conflict with text entry. Directory access, MIME detection, preview
loading and file opening live behind a Platform filesystem adapter. QML UI must not instantiate
`Process`, execute shell commands or write to the filesystem.

Places and its previews are loaded only while the section is visible. Unsupported previews show
metadata instead. Permission failures and missing locations produce an inline recoverable error
state without closing the Launcher.

## Settings section

The existing Settings implementation is reused, not duplicated and not embedded as the current
`SettingsCenter.qml` component verbatim. The current component owns its backdrop, centered panel,
surface-close behavior and settings content, so direct nesting would create conflicting hosts.

Settings is separated into:

- `SettingsWorkspace`: reusable navigation, page loader, preview state and
  Restore/Cancel/Apply controls.
- `SettingsCenter`: the existing standalone overlay host, retaining its IPC entry points and
  using `SettingsWorkspace` internally.
- The Launcher Settings section: loads the same `SettingsWorkspace` inside the Arch Menu content
  area.

Entering Settings begins or resumes one ConfigStore preview transaction. Apply commits
atomically and leaves the Arch Menu open on the Settings section. Cancel rolls the preview back
without closing the Arch Menu. Closing the Arch Menu with unapplied Settings changes cancels the
preview. Existing standalone Settings close behavior remains cancel-and-close.

The Launcher rail remains visible while Settings is selected. The Settings workspace may keep
its own page navigation because it is navigation within that section, not a second global
surface.

## Info and Power sections

Info and Power are separate follow-up batches so their layouts can be reviewed after the core
Launcher is stable.

Info will present host, OS, kernel and Hyprland-session information plus resource summaries.
Resource collection is owned by Platform adapters and is active only while Info is visible.

Power will present large, easy-to-click session actions. Destructive actions such as reboot and
shutdown require confirmation. The exact arrangement is intentionally deferred until that
batch; the existing Platform `SessionActions` remains the execution boundary.

## Architecture

The Launcher remains one transient surface owned by `SurfaceCoordinator`. A lightweight shell
owns popup geometry, rail selection and a lazy content loader. It does not own application,
filesystem, system-information, settings-persistence or session-action logic.

The Launcher module is decomposed into focused units rather than extending `Dashboard.qml`:

- `ArchMenu.qml`: surface-level composition and close behavior.
- `LauncherRail.qml`: section selection contract and icon navigation.
- `AppsPage.qml`: adaptive paging and application presentation.
- `PlacesPage.qml`: three-column file navigation UI.
- `InfoPage.qml`: system-information presentation.
- `PowerPage.qml`: session-action presentation and confirmation.
- `LauncherSectionRegistry.qml`: the only mapping from section IDs to page components.

`LauncherSectionRegistry` permits future sections without hard-coding page-specific behavior in
the shell. Unknown section IDs fall back to Apps and emit a warning.

Dependency direction remains:

`App/Surfaces -> Modules/Composition -> Design/Foundation -> Platform`.

The Arch Menu is closed by outside click, Escape, app launch or monitor focus change. Clicking
inside interactive or non-interactive content never closes it. At most one transient surface is
open per screen.

## State and configuration

Launcher configuration retains density-neutral transition preferences and profile identity.
Obsolete search, category, recent/history and usage-ranking configuration is removed through a
versioned migration. Runtime configuration remains outside the repository and writes remain
atomic.

The active Launcher section and Apps page are ephemeral UI state; opening the Launcher starts on
Apps and the first page. Settings preview state remains owned solely by `ConfigStore`.

## Performance

- Only the current section is loaded; Places previews, Info probes and Power confirmation UI do
  not exist while hidden.
- Apps consumes the existing application catalog without polling.
- Reflow on scale or geometry changes is bounded and does not animate every tile independently.
- No infinite animation, shader, `MultiEffect` or continuous hidden-surface timer is introduced.
- Closing the Launcher releases its heavy page tree through the existing overlay Loader.

## Accessibility and localization

Icon-only rail actions expose localized accessible names and tooltips. Keyboard focus starts on
the selected rail action and moves predictably between rail and content. All user-visible text
uses namespaced `I18n.tr()` keys. Text and grid measurements use logical pixels and must work on
DP-3 at scale 1.0 and DP-1 at scale 1.5.

## Testing and acceptance

Every batch must pass `scripts/check.sh`, `scripts/smoke.sh`, runtime-log inspection and visual
testing on both configured monitors.

Core acceptance criteria:

- The Arch logo is at the left of Workspaces and opens one left-anchored popup.
- The left icon rail and content remain inside a stable Settings-sized popup.
- Apps are alphabetic, adaptive and paginated with correct one-line elision and indicators.
- Wheel paging is horizontal and honors reduced motion.
- No search, favorites, recent list, usage ranking or category UI remains in Apps.
- Places is read-only, lazy and resilient to permission/missing-file failures.
- Embedded and standalone Settings share one workspace implementation and one preview
  transaction contract.
- Closing with unapplied embedded Settings changes rolls them back; Apply writes only runtime
  data outside Git.
- Unknown sections and invalid application entries degrade safely.
- Spotlight source and behavior are not changed by this work.
- UI files contain no `Process`, raw system command or persistence logic.

## Delivery sequence

1. Arch Menu shell, left rail and adaptive Apps.
2. Extract `SettingsWorkspace` and host it in both Settings Center and Arch Menu.
3. Add read-only, lazy Places with the Platform filesystem adapter.
4. Add Info with visibility-gated Platform data.
5. Design and add Power using the existing session-action boundary.

The implementation may proceed through all batches without waiting for visual approval after
each one, as requested. Static and smoke gates still run at every batch so regressions are found
near their source. Final visual and Settings behavior acceptance occurs after the complete plan,
with follow-up adjustments expected.

## Non-goals

- Reworking or merging Spotlight.
- Adding a Launcher keyboard shortcut.
- Implementing filesystem mutation.
- Adding Quick Controls.
- Reintroducing search, favorites, recent-app or usage-ranked app presentation.
- Rewriting Settings pages or changing theme semantics.
- Editing Hyprland theme integration or `hyprland.lua`.
