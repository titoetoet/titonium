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
qs -p "$HOME/Projects/titonium" ipc call arch-menu toggle DP-3
qs -p "$HOME/Projects/titonium" ipc call arch-menu close
qs -p "$HOME/Projects/titonium" ipc call spotlight toggle
qs -p "$HOME/Projects/titonium" ipc call spotlight clipboard
qs -p "$HOME/Projects/titonium" ipc call spotlight close
```

The live Hyprland shortcuts are `Super + Space` for Spotlight Applications and `Super + V` for
Spotlight Clipboard. Both call the project path directly. The MenuBar Arch trigger owns only the
compact system menu; its Settings row opens the same standalone Settings Center used by Settings
IPC. Arch Menu, Spotlight and Settings are separate coordinator owners and never nest their UI.

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

## Spotlight cutover rollback

Restore the recorded pre-cutover Spotlight block in both
`$HOME/.config/hypr/hyprland.lua` and
`$HOME/Projects/titonium-hyprland/config/hypr/hyprland.lua`, then reload Hyprland. Do not overwrite
either file wholesale or disturb its other local changes.

```bash
hyprctl reload
hyprctl configerrors
qs kill -p /home/cole/Projects/titonium
git -C /home/cole/Projects/titonium switch --detach 8fdb106
qs -d -p /home/cole/Projects/titonium
```

The restored block disables the three legacy `qs -c titonium` Spotlight bindings behind
`if false then ... end`. This removes the live V/Space cutover and restores the recorded rollback
state without using `git reset --hard`.

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
