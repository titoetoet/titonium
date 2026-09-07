# Clipboard storage boundary

ClipboardHistory preserves image identity by nonempty digest or path, separately from text.
History retains at most 60 entries and 1 MiB of serialized UTF-8 JSON. Text larger than 64 KiB
is omitted intact (never truncated into a different clipboard value). The watcher reads at most
64 KiB + 1 byte for text and 16 MiB + 1 byte for PNG images from the triggering callback's stdin.
These limits apply only to captured history; they do not overwrite the system clipboard.

Image capture uses `$XDG_DATA_HOME/titonium/clipboard-images`, falling back to
`~/.local/share/titonium/clipboard-images`. Each capture writes a private, unique digest/UUID file.
Remove, clear, duplicate replacement, and eviction queue old paths for cleanup only after the
latest history snapshot saves successfully. A failed save retains its referenced image files;
a newer pending snapshot is still submitted. Cleanup operates only on regular, directly contained
cache files with the owned filename format and refuses cache-directory symlinks. It does not scan
or delete arbitrary unreferenced files left by older versions or interrupted captures.

`copyImage()` returns whether an asynchronous operation was accepted; it rejects a concurrent copy.
The helper reports missing files, missing `wl-copy`, command failure, and a ten-second timeout.
Completion updates the existing `available` / `error` service properties.

Isolated checks (no running shell, app launch, or system clipboard access):

```sh
node scripts/check_clipboard_regressions.js
python3 scripts/check_clipboard_io.py
```
