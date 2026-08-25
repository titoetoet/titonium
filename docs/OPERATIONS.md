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

MenuBar transient surfaces expose test-only lifecycle endpoints without requiring a keybinding:

```bash
qs -p "$HOME/Projects/titonium" ipc call calendar toggle DP-3
qs -p "$HOME/Projects/titonium" ipc call launcher toggle DP-3
qs -p "$HOME/Projects/titonium" ipc call launcher close
```

Settings lifecycle and page endpoints:

```bash
qs -p "$HOME/Projects/titonium" ipc call settings openPage theme DP-3
qs -p "$HOME/Projects/titonium" ipc call settings openPage typography DP-3
qs -p "$HOME/Projects/titonium" ipc call settings openPage layout DP-3
qs -p "$HOME/Projects/titonium" ipc call settings openPage frame DP-3
qs -p "$HOME/Projects/titonium" ipc call settings previewMode light
qs -p "$HOME/Projects/titonium" ipc call settings previewBarHeight 48
qs -p "$HOME/Projects/titonium" ipc call settings previewFrame true
qs -p "$HOME/Projects/titonium" ipc call settings close
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
