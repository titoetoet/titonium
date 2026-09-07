# Settings release review — 2026-09-07

## Changes

- Page titles and “Reset this page” share a single persistent header, including when the page scrolls. About remains read-only with no page reset.
- Bar and Dock content scroll within the page, above the fixed Apply footer. Dock mode choices use two columns at the normal Settings width; the application editor reserves enough height for its catalog. Notifications exposes a scrollbar.
- Setting labels wrap, and the control slot measures intrinsic widths without depending on right-anchored child positions.
- Settings dimensions stay within the owning screen with a 24 px margin.
- Primary buttons retain the contrasting accent text when disabled; disabled opacity still signals availability. This fixes the nearly invisible Apply label after a theme change.
- Select emits changes to its owner without overwriting the owner's `currentIndex` binding. External resets now update both the displayed choice and the native ComboBox index after keyboard selection.
- Page editing is disabled while Settings is saving.
- External Settings updates now reload FileView's cached contents asynchronously and publish only after loading completes. Preview/write guards remain intact. This also fixes external Connected/Classic changes retaining the previous presentation. Quickshell requires explicit reload on filesystem events; see [FileView documentation](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/).

## Evidence

- `scripts/check.sh`: passed, including the existing preference migration, reset-path, transactional appearance, save failure, trial rollback, undo, wallpaper and QML lint gates.
- `scripts/check_settings_ui.py`: passed at scale 1 and 1.5. Real Settings presentation components, inert native/persistence boundaries, eight pages, English/Vietnamese, dark/light, 980×700 and 820×600. Populated app, pin and notification fixtures. Checks title/reset alignment, button widths, reachable Bar/Dock content, dropdown reset after keyboard selection and primary-label contrast for all five design styles in both modes and enabled states.
- `scripts/smoke.sh`, `scripts/settings_acceptance.sh`, `scripts/protected_acceptance.sh`: passed from a temporary repository snapshot matching the final Settings/control sources. The snapshot avoids Quickshell's no-duplicate guard against the running user shell.
- `scripts/check_preferences_runtime.py`: passed with actual Quickshell FileView/IPC, temporary settings files, repeated atomic replacements and preservation of an active draft.
- Native notification acceptance is skipped on the user bus because its notification name is already owned. On a private D-Bus session, with temporary layer checks scoped to the fixture PID, all passive/critical and Connected→Classic→Connected lifecycle assertions completed. The final log gate still rejects a host desktop-portal registration warning (`Connection already associated with an application ID`); this isolated run is not recorded as a clean acceptance pass.
- `hyprctl configerrors`: empty.
- `git diff --check`: passed.
- Live DP-1 inspection at 150% confirmed the repaired Bar header, footer separation and readable Apply label.
- Independent review found the small-window Dock catalog starvation; fixed with scrolling and a populated catalog viewport regression test. No other concrete issue reported in the focused changes.

## Scope

This is a Settings readiness review, not a published release. Existing unrelated working-tree changes were preserved. Automated tests do not launch applications, overwrite clipboard contents, or change either Hyprland configuration. Hardware/backend availability remains outside isolated presentation coverage.
