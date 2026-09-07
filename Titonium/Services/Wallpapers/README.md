# Wallpapers sidecar

Local catalog → selection/preview → explicit Apply to the supplied exact output.
No downloads, daemon startup, Hyprland/hyprpaper config edits, preload/unload
sequence or output fallback. Appearance adds explicitly opted-in managed restore
and bounded startup retries, described below.

## Integration contract (wired into Expanded)

1. Add `WallpapersContent 1.0 WallpapersContent.qml` to `Titonium/Bar/center/qmldir`.
2. Mount `WallpapersContent` in the Wallpapers tab body, passing the host's
   `screenName`. Its implicit size is 700 × 420; it fills the assigned space.
3. Prefer a Loader active only for the visible Wallpapers tab. If the host retains
   the component, bind `active` to the selected tab AND expanded-surface visibility.
   `active` defaults to true and is combined with effective `visible`. The view
   acquires/releases a singleton lease on changes and destruction. Do **not** bind
   `WallpapersService.active` directly; it is derived from all consumer leases.
4. Merge `translation-keys.json`'s `en` and `vi` maps into the corresponding
   `config/i18n/*.json` `strings` objects. Until integrated, I18n displays keys.
5. Add `python3 scripts/check_wallpapers.py` to the owner's check pipeline.

The only new module export is `qs.Titonium.Services.Wallpapers.WallpapersService`.
Public facts: `active`, `busy`, `items`, `directory`, `available`, `truncated`,
`statusKey`, `applied` (successful applies in this process, keyed by screen).
Intents: `setVisible(consumer, visible)`, `refresh(directory)`,
`applyTo(screenName, catalogItemPath)`. The view owns only preview selection.
Appearance also uses this singleton for its journal, baseline and capability contract.
The process executable path uses `Quickshell.shellPath`, verified in a real
offscreen Quickshell session, rather than relying on provider-URL conversion.

## Local discovery and limits

Read-only inspection on 2026-09-06 found hyprpaper **v0.8.4**, no running daemon,
and `~/.config/hypr/hyprpaper.conf` wallpaper blocks for DP-1 and DP-3 pointing to
`/home/cole/Pictures/Wallpapers/5.jpg`. The inferred default directory is therefore
`/home/cole/Pictures/Wallpapers`. Hyprpaper was subsequently started at the user’s
request to enable switching; see the managed Appearance configuration below.

On each activation or explicit refresh the helper reads up to 64 KiB of the
standard XDG hyprpaper config and discovers directories from literal `path =`
entries. It does not evaluate configuration variables, includes or custom daemon
config paths. The editable absolute-directory field remains available if discovery
fails or the user wants a different local directory. Direct children only:
PNG/JPEG/WebP, at most 128 images / 1,024 visited entries / four seconds of scan
work (plus the current probe, at most one second). A cap displays a truncation
notice. No recursive traversal; symlinks, animated/multi-frame images, corrupt
headers, files above 32 MiB or images above 40 million pixels are omitted.
Oversized images can be exported smaller outside Titonium. The read-only local
scan admitted 1.jpg, 5.jpg and 6.jpg; the other three exceeded the pixel cap.
Raster signatures determine the decoder, so the PNG stored as 6.jpg is supported.

Dependencies are Python 3, ImageMagick 7 (`magick`), and `hyprctl` for the installed
hyprpaper 0.8 API. ImageMagick receives explicit raster coder prefixes, bounded
resources and timeouts, never shell text. Thumbnail and preview Images use bounded
`sourceSize`, asynchronous loading, no QML image cache, and a virtualized grid.
No thumbnail files or persistent catalog are written. Hidden catalogs are dropped.

Apply revalidates catalog membership, direct-child path, dimensions, full decode,
API availability and the current exact compositor monitor name. Empty names,
wildcards, descriptions, commas and control characters cannot reach the backend.
It issues exactly one argv-based `hyprctl hyprpaper wallpaper
<screen>,<absolute-path>,cover`, with no retry or unload. Failures preserve the
service's applied map and previous stored record. Closing the tab cancels catalog
work; an already explicitly requested Apply is allowed to finish and record its
outcome. No further work starts while hidden.

Only backend success writes an atomic, mode-0600 record to
`$XDG_STATE_HOME/titonium/wallpapers/<screen>.json` (default
`~/.local/state/titonium/wallpapers/`). Paths under the source checkout are rejected.
The catalog record remains an audit of the last accepted request. Separate
explicitly enabled managed state supports Appearance restoration; catalog records
alone never authorize a restore. Persistence failure after
backend success reports a distinct warning and does not repeat Apply.

## API evidence and limitations

Local `hyprctl hyprpaper --help` advertises only `wallpaper` with optional fit mode;
the old `reload` API is not supported here. The official
[hyprpaper documentation](https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/) also
directs callers to installed help. Protocol review used hyprwm/hyprpaper **v0.8.4**,
BSD-3-Clause, specifically
[`src/ipc/IPC.cpp`](https://github.com/hyprwm/hyprpaper/blob/v0.8.4/src/ipc/IPC.cpp)
and [`src/config/WallpaperMatcher.cpp`](https://github.com/hyprwm/hyprpaper/blob/v0.8.4/src/config/WallpaperMatcher.cpp).
No third-party implementation was copied. A one-shot process boundary is used
because Quickshell has no native hyprpaper model in this environment.

The daemon accepts the request before final rendering. Prevalidation and avoiding
unload preserve the current wallpaper on validation and reported backend failures;
there is no atomic rendered-frame acknowledgement/rollback guarantee if a file
changes between validation and daemon decode, the daemon crashes after accepting,
or a timeout occurs after delivery. The UI does not report those as confirmed
success or retry them. Availability is an advisory socket/help check; Apply
rechecks and handles a stopped/disconnected daemon. Automated tests never change the live desktop. Explicitly requested manual
configuration and switching are verified separately.

## Verification

`python3 scripts/check_wallpapers.py` exercises real helper processes and QML with
temporary image directories, a fake `hyprctl` executable and a temporary Unix
socket. It never sends Apply to the real daemon. Includes validation, missing
screen/file, literal argv, decode/backend failure, success-only persistence,
multiple visibility leases, selection-only preview and view destruction.
The sandbox may require permission for the fake Unix socket and offscreen qs.

Focused qmllint loads both new QML files. This installation reports the same
Quickshell metadata warning as existing services for `QProcess::ExitStatus` in
`Process.onExited`; no unavailable view properties or bindings were reported.
The shared pipeline registers this fixture. Expanded mounts the view only for the
Wallpapers tab; locale maps are merged into the English/Vietnamese catalogs.
Shared-shell smoke/protected acceptance is recorded in `docs/TESTING.md`.


## Managed Appearance configuration (Hyprpaper 0.8.4)

This version cannot query the active wallpaper. Explicit initialization applies a
known baseline to DP-1 before enabling theme/custom wallpaper trials:

```sh
python3 Titonium/Services/Wallpapers/wallpapers.py appearance-initialize '{"screen":"DP-1","path":"/home/cole/Pictures/Wallpapers/5.jpg","fit":"cover"}'
```

Run from the checkout with Hyprpaper already running. This is a real wallpaper
change and durable opt-in, not a read-only probe. Runtime records remain under
`$XDG_STATE_HOME/titonium/wallpapers`, outside Git. Hyprpaper’s existing login
startup remains responsible for the daemon.

Titonium tracks acknowledged wallpaper changes against the daemon socket/session.
Trials update the session baseline; successful Apply updates the committed managed
wallpaper. On a new daemon session, recovery reapplies the managed committed path
to establish a known baseline, then follows the saved Appearance policy. Pending
trial journals are resolved first. The service retries unavailable-daemon startup
up to ten times at 500 ms intervals; the Settings retry action can recover later.
DP-3 is not part of Appearance’s managed restoration.

Change wallpapers through Titonium while this mode is enabled. External
`hyprctl hyprpaper wallpaper` commands cannot be observed on 0.8.4 and invalidate
the tracked assumption; reinitialize with the desired baseline after such changes.
IPC success confirms daemon acceptance, not final rendered-frame completion.
