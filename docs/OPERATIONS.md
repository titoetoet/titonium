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
qs -p "$HOME/Projects/titonium" ipc call arch-menu previewSessionAction lock
qs -p "$HOME/Projects/titonium" ipc call arch-menu close
qs -p "$HOME/Projects/titonium" ipc call spotlight toggle
qs -p "$HOME/Projects/titonium" ipc call spotlight clipboard
qs -p "$HOME/Projects/titonium" ipc call spotlight close
```

The live Hyprland shortcuts are `Super + Space` for Spotlight Applications and `Super + V` for
Spotlight Clipboard. Both call the project path directly. The MenuBar Arch trigger owns only the
compact system menu; its Settings row opens the same standalone Settings Center used by Settings
IPC. A session row replaces the menu with a dedicated centered confirmation. The preview endpoint
above is acceptance-only: close/cancel it and never automate its confirm control. Arch Menu,
Spotlight and Settings are separate coordinator owners and never nest their UI.

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

Rollback commit `8fdb106` has no Spotlight IPC handler. Before reloading Hyprland, edit both
`$HOME/.config/hypr/hyprland.lua` and
`$HOME/Projects/titonium-hyprland/config/hypr/hyprland.lua`. In each file, replace only the two
active Spotlight `hl.bind` lines for `Super + V` and `Super + Space` with this exact Lua comment
block; do not add a `Super + R` Spotlight binding and do not restore the old `qs -c titonium`
commands:

```lua
-- Rollback shell 8fdb106 has no Spotlight IPC handler.
-- Super + V, Super + R and Super + Space intentionally have no Spotlight binding.
```

Verify that neither file contains a Spotlight Clipboard/toggle command. The following command must
print nothing and exit with status 1:

```bash
rg -n 'spotlight (clipboard|toggle)' \
  "$HOME/.config/hypr/hyprland.lua" \
  "$HOME/Projects/titonium-hyprland/config/hypr/hyprland.lua"
```

Only after that no-match result, reload Hyprland and start the rollback shell. Do not overwrite
either Lua file wholesale or disturb its other local changes.

```bash
hyprctl reload
hyprctl configerrors
qs kill -p /home/cole/Projects/titonium
git -C /home/cole/Projects/titonium switch --detach 8fdb106
qs -d -p /home/cole/Projects/titonium
```

This removes the live V/Space cutover and leaves V, R and Space unable to call missing Spotlight
IPC while `8fdb106` is running, without using `git reset --hard`.

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
