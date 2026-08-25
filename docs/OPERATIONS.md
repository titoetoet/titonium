# Operations and rollback

## Greenfield runtime

```bash
qs -n -p "$HOME/Projects/titonium"
qs -n -d -p "$HOME/Projects/titonium"
qs -p "$HOME/Projects/titonium" ipc call app status
```

Milestone 0 also exposes config IPC methods `beginPreview`, `apply`, and `cancel` for
acceptance testing. Typed patch commands are added with the Settings Center phase.

Theme Foundation adds `config restoreAppearance` and the lazy Gallery endpoints:

```bash
qs -p "$HOME/Projects/titonium" ipc call gallery toggle DP-3
qs -p "$HOME/Projects/titonium" ipc call gallery state
qs -p "$HOME/Projects/titonium" ipc call gallery previewMode light
qs -p "$HOME/Projects/titonium" ipc call gallery close
```

## Legacy rollback

The legacy source is retained read-only in Trash at
`~/.local/share/Trash/files/titonium`. Restore the directory before launching it:

```bash
qs kill -p "$HOME/Projects/titonium"
mv "$HOME/.local/share/Trash/files/titonium" "$HOME/.config/quickshell/titonium"
qs -n -d -c titonium
```

Restore the Hyprland autostart command to `qs -n -d -c titonium` and reload Hyprland if a
persistent rollback is needed. Feature keybindings are restored only with their owning module.
