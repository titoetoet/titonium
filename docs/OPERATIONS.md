# Operations

## Start, inspect and stop

```bash
qs -d -p /home/cole/Projects/titonium
qs -p /home/cole/Projects/titonium ipc call app status
qs -p /home/cole/Projects/titonium kill
```

Quickshell hot-reloads watched source files. For architecture changes or acceptance tests, stop the
daemon first so a foreground instance can own the shell ID, then restart it afterwards.

## Protected IPC

```bash
qs -p /home/cole/Projects/titonium ipc call spotlight toggle
qs -p /home/cole/Projects/titonium ipc call spotlight clipboard
qs -p /home/cole/Projects/titonium ipc call spotlight close
```

Hyprland owns `Super + Space` and `Super + V`. Feature work must not edit or reload either
`/home/cole/.config/hypr/hyprland.lua` or the dotfiles copy. `protected_acceptance.sh` verifies
their hashes and bindings.

## Recovery

If the current daemon fails, stop it and inspect foreground output:

```bash
qs -p /home/cole/Projects/titonium kill
qs -p /home/cole/Projects/titonium
```

The pre-contraction runtime can be inspected from Git commit `62f8ba1`; do not copy it over the
working tree. Use Git history to extract one file into a temporary location when researching an
old interaction. Runtime preferences and clipboard history remain in Quickshell's Titonium data
directory and are not removed during source rollback.
