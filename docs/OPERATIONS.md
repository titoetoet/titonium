# Operations and rollback

## Greenfield runtime

```bash
qs -n -p "$HOME/Projects/titonium"
qs -n -d -p "$HOME/Projects/titonium"
qs -p "$HOME/Projects/titonium" ipc call app status
```

## Legacy rollback

The legacy source remains at `~/.config/quickshell/titonium`.

```bash
qs kill -p "$HOME/Projects/titonium"
qs -n -d -c titonium
```

Restore the Hyprland autostart command to `qs -n -d -c titonium` and reload Hyprland if a
persistent rollback is needed. Feature keybindings are restored only with their owning module.

