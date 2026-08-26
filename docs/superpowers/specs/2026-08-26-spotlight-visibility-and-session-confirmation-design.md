# Spotlight visibility and centered session confirmation

Date: 2026-08-26

Status: approved

## Scope

This batch completes five related interaction corrections without changing Titonium's visual
theme: session confirmation becomes its own centered transient surface; Spotlight grows upward
under the MenuBar; application scope icons move outside Search; existing categories classify
installed applications more accurately; page indicators communicate application density; and
users can hide applications globally from Titonium through the Spotlight settings page.

Wi-Fi, Bluetooth, Sound and Notification Toast remain the next independent milestone. They are
not implemented or stubbed by this batch.

## Architecture

Dependency direction remains:

`App/Surfaces -> Modules/Composition -> Design/Foundation -> Platform`

`Platform.Applications.ApplicationCatalog` remains the unfiltered desktop-entry boundary and the
only application launch adapter. A Foundation singleton owns visibility projection over that raw
catalog and configuration preview state. Modules consume the Foundation projection for display
but continue to call the Platform adapter for launch by desktop-entry ID.

`SurfaceCoordinator` continues to allow only one transient surface per screen. Opening a session
confirmation replaces the Arch Menu owner/descriptor with a dedicated confirmation owner and
source; Titonium never keeps the dropdown and confirmation surface alive concurrently.

No UI component may instantiate `Process`, execute a command or persist data.

## Centered session confirmation

Every session action—Lock, Sleep, Hibernate, Logout, Restart and Shutdown—uses the same flow:

1. The user activates the item in Arch Menu.
2. Arch Menu opens a descriptor owned by `session-confirm:<screen>:<action>` whose source is the
   dedicated session-confirmation surface.
3. Surface replacement removes the Arch Menu tree.
4. The confirmation panel is centered on the screen that owned Arch Menu and requests exclusive
   keyboard focus.
5. Cancel or Escape closes the confirmation entirely and does not reopen Arch Menu.
6. Confirm delegates to `Platform.System.SessionActions.executeConfirmed(actionId)`.
7. Accepted/successful action lifecycle closes the surface. Start/command failure releases the
   owner guard, keeps the confirmation visible and renders the localized failure.

The panel is 420 logical pixels wide with a 240-pixel minimum height and a 320-pixel maximum;
localized content scrolls inside that bound if necessary. Restart and Shutdown retain danger
semantics; all other actions retain warning or primary semantics. Outside click behaves like
Cancel only while no action is pending. An accepted action cannot be cancelled or dismissed until
its existing lifecycle contract resolves.

Automated and manual acceptance may exercise only Cancel/Escape and injected lifecycle fakes.
They must never confirm a real lock, sleep, hibernate, logout, restart or shutdown.

## Spotlight placement and header

Spotlight remains 800 logical pixels wide. Its height becomes responsive with a target maximum of
760 logical pixels, constrained by the available screen height below the MenuBar and a safe bottom
margin. It is horizontally centered and top-anchored at `MenuBar height + 12 logical pixels`,
rather than vertically centered. It must remain fully visible at the supported 1.0 and 1.5 output
scales.

The header is one row. A scope icon sits outside and immediately to the left of the Search field:

- Applications: `rocket_launch`
- Clipboard: `content_paste`
- mock System Search: `manage_search`

The Search field contains no leading icon. The existing single-surface scope cycle remains:
Tab advances Applications → Clipboard → System Search → Applications; Shift+Tab reverses it; the
query and Search focus are preserved; only the Loader-owned body changes.

## Application categories

No new top-level category is added. The stable visible order remains:

`All, Development, Games, Graphics, Internet, Multimedia, Office, System, Utilities, Other`

Only non-empty groups render. Category aliases expand to cover common freedesktop subcategories,
including:

- Development: `IDE`, `Building`, `GUIDesigner`, `WebDevelopment`
- Games: freedesktop game subcategories
- Graphics: `2DGraphics`, `3DGraphics`, `Photography`, `RasterGraphics`, `VectorGraphics`
- Internet: `WebBrowser`, `Email`, `InstantMessaging`, `FileTransfer`, `P2P`, `RemoteAccess`
- Multimedia: `Audio`, `Video`, `Player`, `Recorder`, `TV`
- Office: `WordProcessor`, `Spreadsheet`, `Presentation`, `Database`, `Finance`, `Calendar`
- System: `Settings`, `DesktopSettings`, `HardwareSettings`, `PackageManager`, `Monitor`, `Security`
- Utilities: `FileManager`, `FileTools`, `Archiving`, `Calculator`, `TextEditor`, `Accessibility`

An application may appear in multiple meaningful groups when its desktop entry declares multiple
recognized categories. Apps with no recognized category remain in Other. Search continues to
cover all visible applications regardless of the selected browse category.

## Density indicators

The fixed background tracks are removed. Each page owns one standalone rounded pill whose actual
width communicates occupancy:

`12 + 44 × clamp(page app count / 20, 0, 1)` logical pixels

This yields 56 pixels for a full page, 23 pixels for five apps and 12 pixels for an empty page.
The visual pill may be smaller than its transparent 56×20 pointer/keyboard target. The current
page uses accent; other pages use a neutral semantic color. The accessible name includes page
number, current app count and capacity. Indicator width is derived only from the page array and
fixed 5×4 capacity.

## Global application visibility

Settings schema v5 adds the global subtree:

```json
{
  "applications": {
    "hiddenIds": []
  }
}
```

Migration v4→v5 creates an empty list and preserves every existing appearance, accessibility,
locale, layout and module value. Validation accepts unique non-empty desktop-entry ID strings and
rejects duplicate, non-string or unknown fields. Runtime persistence continues to use
`ConfigStore` preview/apply/cancel and atomic writes outside the repository.

The Foundation visibility singleton exposes:

- `allApplications`: raw installed records from `ApplicationCatalog`
- `visibleApplications`: records whose IDs are absent from preview `applications.hiddenIds`
- pure helpers for normalized hidden-ID membership and toggling

Missing/uninstalled IDs remain persisted so reinstalling an intentionally hidden application does
not unexpectedly expose it. The Settings list shows installed records only and always reads
`allApplications`, so every currently installed hidden application can be restored.

All Titonium application grids, searches and future application pickers must consume
`visibleApplications`. Launch still delegates by ID to `ApplicationCatalog`; visibility policy
does not grant or revoke execution capability.

## Spotlight settings UI

Application visibility is managed inside the existing Spotlight page, not through a separate
navigation page. The page keeps its transition controls and adds an `Applications shown` section:

- a local, non-persisted search field filters the settings list by application name;
- each installed application row displays its icon, one-line elided name and a visibility switch;
- switch on means visible; switch off means globally hidden in Titonium;
- the list is lazy/viewport-bound and must not create one expensive tree for every installed app;
- changing a switch patches preview state immediately;
- Cancel restores the exact committed visibility set; Apply persists it atomically.

The settings UI never filters its own source through `visibleApplications`; otherwise hidden apps
would disappear before the user could restore them.

## Error handling and performance

- Unknown application IDs in settings are retained but do not render without an installed record.
- A disappearing desktop entry during preview is ignored safely.
- Unknown session actions are rejected before a confirmation descriptor opens.
- Surface owner guards continue to protect pending session actions.
- Category and visibility projection are pure/event-driven; no timer or command polling is added.
- The confirmation tree and Settings application delegates exist only while their surfaces are
  active. No infinite animation, shader, `MultiEffect` or hidden render loop is permitted.

## Acceptance

### Static and fixture gates

- Settings v4 migrates to v5 with an empty hidden-ID list and unrelated state unchanged.
- Valid hidden IDs pass; duplicate, empty, non-string and unknown visibility fields fail.
- Visibility helpers filter, toggle and retain missing IDs deterministically.
- Spotlight category fixtures cover the installed-style aliases listed above and hide empty groups.
- Density fixtures prove full, partial and minimum pill widths plus accessible count text.
- Architecture checks require the dedicated confirmation surface, forbid nested confirmation in
  Arch Menu, and require app consumers to use the Foundation visibility projection.
- `qmllint` has no errors beyond existing narrow Quickshell metadata allowlists.

### Runtime gates

- Foreground smoke reaches `Configuration Loaded` without QML/runtime errors.
- Spotlight is top-anchored, fully visible and taller on both supported scales.
- The scope icon is outside Search and changes with Apps/Clipboard/System Search.
- Tab scope cycling preserves query/focus and the panel never closes or resizes.
- Full and partial application pages render visibly different pill lengths.
- Hiding an app in preview immediately removes it from Spotlight browse/search; Cancel restores it.
- Apply changes only runtime settings outside the repository.
- Each Arch Menu session item opens the centered dedicated confirmation source on the correct
  screen. Cancel/Escape closes it without executing any session action.
- `hyprctl configerrors` is empty; runtime logs contain no ERROR, TypeError, missing member,
  unavailable lazy type or duplicate ID.

## Next milestone

After this batch passes and remains live, implementation proceeds to a separate milestone for
Wi-Fi, Bluetooth, Sound and Notification Toast. That milestone will define event-driven Platform
adapters and independent module contracts before any UI is ported from the read-only legacy
reference.
