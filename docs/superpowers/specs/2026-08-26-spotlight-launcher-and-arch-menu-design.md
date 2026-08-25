# Spotlight Launcher and Arch Menu Design

**Date:** 2026-08-26  
**Status:** Approved in conversation; awaiting written-spec review

## Purpose

Separate application discovery from the MenuBar system menu. Spotlight becomes a keyboard-first
application launcher that also supports browsing a categorized application grid. The Arch logo
opens a compact macOS-style system menu instead of a Settings-sized dashboard.

This design supersedes the surface responsibilities in
`2026-08-25-arch-menu-launcher-design.md`. It preserves the tested application catalog, paging,
indicator, Settings workspace and session-action boundaries rather than porting the current large
Arch Menu intact.

## Surface responsibilities

### Spotlight Launcher

Spotlight is a centered transient surface on the focused screen. It has nominal dimensions of
800 by 620 logical pixels and is constrained to the available screen geometry. Its dimensions do
not change when switching between the application grid, search results and Clipboard mode.

`Super + Space` toggles the default Spotlight Launcher. `Super + V` opens it directly in
Clipboard mode. The obsolete duplicate `Super + R` binding is removed. These bindings call the
new Titonium IPC contract directly and do not enter a Hyprland submap.

On every normal open, Spotlight starts with an empty query, the `All` category, page one and the
search field focused. Its default body is a five-column by four-row application grid. A vertical
mouse-wheel gesture pages the grid horizontally. Page indicators preserve the existing
occupancy-based length: a full page has a longer indicator and a partially filled page has a
proportionally shorter indicator; active state changes color rather than length.

The category row is normalized from desktop-entry metadata and ordered as:

`All`, `Development`, `Games`, `Graphics`, `Internet`, `Multimedia`, `Office`, `System`,
`Utilities`, `Other`.

Empty categories are hidden. An application may appear in more than one applicable category.
Applications with no recognized category appear in `Other`. Each category and `All` is sorted
alphabetically.

Typing transitions the grid to a vertical result list without resizing the surface. Search
always covers the complete application catalog regardless of the selected browse category and
also recognizes calculator expressions. The selected browse category is retained while search
is active. Clearing the query returns to that category and page state.

Up and Down move the result selection. Enter executes the selected result, with the first result
selected by default. Escape clears a non-empty query and returns to browse mode; a second Escape
closes Spotlight. Invalid calculator input remains an ordinary text query. Application launch
closes Spotlight; a failed or stale desktop entry is logged and degrades safely.

Clipboard mode uses the same stable surface but loads a list-and-preview workspace. It is entered
directly through `Super + V`, not mixed into normal application results. File search is deferred
to a later provider milestone because the legacy Files mode is only a stub. System session and
power actions are excluded from Spotlight and remain owned by the Arch Menu.

### Arch Menu

Clicking the Arch logo at the left edge of the MenuBar opens a compact dropdown anchored below
that icon. The menu uses text labels, small leading icons and separators between groups. It is
not a navigation rail, application grid, Settings host or keyboard launcher.

The intended complete menu is:

1. About Titonium; System Information.
2. System Settings; Task Manager.
3. Lock Screen; Sleep; Hibernate.
4. Restart; Shut Down.
5. Log Out.

Separators divide the numbered groups. Items whose owning module does not yet exist are not
rendered as dead placeholders; they are added when that roadmap milestone supplies a functional
target. About opens a focused Titonium information surface. System Settings closes the Arch Menu
and opens the standalone Settings Center. System Information and Task Manager delegate to their
future system-module surfaces.

Every session or power action, including Lock and Sleep, requires confirmation. A shared
macOS-inspired confirmation sheet states the requested action and its consequence, focuses
Cancel by default and labels the action button with the exact operation. Destructive actions use
the semantic danger tone. There is no countdown and no automatic execution. Confirmation emits
an action request to the Platform `SessionActions` adapter; UI code never executes a command.

## Settings reversal

Settings is removed from the Arch Menu content tree. `SettingsCenter` remains the only Settings
surface and continues to provide Preview, Apply, Cancel and scoped restore behavior. The existing
`SettingsWorkspace` extraction is retained because it cleanly separates Settings content from
its surface host. `LauncherSettingsPage`, Launcher section registration and Launcher-specific
preview-close coupling are removed.

Selecting System Settings in the Arch Menu closes the current transient surface before opening
Settings Center through `SurfaceCoordinator`, preserving the one-transient-per-screen rule.

## Architecture and contracts

The two features are separate modules:

- `Titonium.Modules.Spotlight` owns `SpotlightSurface`, `SpotlightModel`, `AppGrid`,
  `SearchResults`, `CategoryCatalog` and `ClipboardView`.
- `Titonium.Modules.MenuBar.ArchMenu` owns the Arch trigger/dropdown, menu registry and
  confirmation presentation.

The current broad `Modules/MenuBar/Launcher` implementation is decomposed rather than renamed
wholesale. Reusable application tiles, pure paging helpers and indicators move to a neutral
application-presentation boundary or are reimplemented as focused Spotlight components when
their existing API is Launcher-specific. Arch Menu must not depend on Spotlight UI, and
Spotlight must not depend on the MenuBar.

Both consume `Platform/Applications/ApplicationCatalog`. Provider results use a normalized data
contract with stable ID, type, title, subtitle, icon, score and opaque execution reference.
Provider execution stays behind Platform/Foundation adapters. UI code owns selection and
presentation only.

`SurfaceCoordinator` remains responsible for focus, outside-click handling, monitor fallback,
click masks and the rule that only one transient surface may be open on a screen. Opening one of
Spotlight, Arch Menu or Settings replaces the current transient cleanly. Heavy content is loaded
only while its surface and mode are active.

Dependency direction remains:

`App/Surfaces -> Modules/Composition -> Design/Foundation -> Platform`.

No UI file may instantiate `Process`, call `Quickshell.execDetached`, persist data, or contain raw
`hyprctl`, clipboard or session commands.

## State and configuration

Query, selected category, page and result selection are ephemeral. A normal reopen resets them
to `All`, page one and an empty query. Clipboard direct-open resets its own selection and query.

Only durable user preferences belong in settings, such as transition style, transition duration
and reduced motion. The migration removes settings that exist solely for the retired Arch Menu
rail or embedded Settings host. Runtime settings continue to live outside Git and Apply remains
atomic.

## Motion and performance

Grid-to-results transitions use short opacity and position animations. Existing Launcher motion
preferences may be migrated to the Spotlight namespace. Reduced motion resolves all such
durations to zero.

Application browsing and search operate on the event-updated application catalog cache and do
not poll. Category normalization and search ranking are pure functions with fixture coverage.
Only the active Grid, Results or Clipboard view is loaded. Closed surfaces release their heavy
tree. No infinite animation, shader, `MultiEffect`, hidden timer or idle render loop is added.

## Error handling

- Unknown desktop categories map to `Other`.
- Empty categories are hidden without changing the stable category order.
- Invalid or stale application entries are skipped or reported through the application adapter.
- An unavailable Clipboard adapter produces a localized empty/error state and does not crash.
- Invalid calculator expressions remain normal queries.
- Unknown Arch Menu item IDs log a warning and do nothing.
- A rejected or failed session action leaves the confirmation visible with an actionable error;
  it never silently retries.
- If the focused screen cannot be resolved, surfaces fall back to the first available screen and
  log a warning.

## Accessibility and localization

Every visible string uses namespaced `I18n.tr()` keys. Category chips, application tiles, result
rows, Arch Menu items and confirmation controls expose accessible roles, names and focus states.
Keyboard navigation never requires pointer input. Logical geometry must remain usable on DP-3
at scale 1.0 and DP-1 at scale 1.5.

## Testing and acceptance

Implementation follows test-first slices. Pure fixtures cover category normalization, fixed 5x4
paging, indicator fill ratios, search ranking, calculator parsing and state transitions.

Acceptance requires:

- `Super + Space` opens default Spotlight and `Super + V` opens Clipboard; `Super + R` no longer
  invokes Spotlight.
- Spotlight opens centered on the focused monitor at stable geometry.
- Browse mode renders exactly five columns and four rows per page.
- Category order, hidden-empty behavior, multi-category membership and `Other` fallback are
  deterministic.
- Search ignores the selected browse category and the first result executes on Enter.
- Escape clears search before it closes the surface.
- Wheel input pages horizontally and occupancy indicators retain their fullness semantics.
- Arch click opens only the compact text-and-icon menu.
- Settings opens as its standalone surface and retains Preview, Apply, Cancel and restore.
- Every session/power action is confirmed and executes only through `SessionActions`.
- Unknown or unavailable data sources degrade without a QML exception.
- `scripts/check.sh`, `scripts/smoke.sh`, runtime-log inspection and `hyprctl configerrors` pass.
- Visual acceptance passes on DP-3 scale 1.0 and DP-1 scale 1.5.
- Idle behavior contains no polling, hidden animation, shader or continuous effect.

## Delivery sequence

1. Extract and test neutral application paging/category/search contracts.
2. Build the Spotlight shell and fixed 5x4 categorized browse mode.
3. Add the application/calculator result list and keyboard state machine.
4. Port Clipboard behind its Platform adapter and add direct-open mode.
5. Replace the large Arch Menu with the compact dropdown and shared confirmation flow.
6. Restore standalone Settings-only ownership and remove obsolete Launcher hosts/settings.
7. Cut over Hyprland bindings, then run static, runtime, multi-monitor and rollback acceptance.

## Non-goals

- File search in the first Spotlight delivery.
- System or power actions in Spotlight results.
- Recent/favorite/usage-ranked applications.
- Search inside the Arch Menu.
- Dead placeholders for future System Information or Task Manager modules.
- Rewriting Settings pages or changing theme semantics.
- Editing `hyprland.lua` for visual themes or compositor material synchronization.
