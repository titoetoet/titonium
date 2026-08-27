# Titonium

Titonium is a small Quickshell skeleton for Hyprland, built to accept independently sourced
modules without turning the shell into a coupled framework. The current baseline intentionally
keeps only the distinctive Spotlight flow, the smooth Fcitx input indicator, a direct dynamic
multi-monitor bar, shared tokens and narrow platform services.

## Current UI

- A 44 logical-pixel bar is created reactively for every enabled screen entry.
- The temporary bar contains Workspaces, Input Method and Clock.
- `Super + Space` opens Spotlight Applications; `Super + V` opens Clipboard.
- Spotlight supports its 5×4 app grid, categories, calculator results, density indicators,
  Clipboard scope and the System Search mock.

Settings Center, Arch Menu, Active Window, Calendar, Theme Gallery, Frame and Audio were removed
from the runtime baseline. They are historical reference in Git, not dependencies of the shell.

## Run and verify

```bash
cd /home/cole/Projects/titonium
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
qs -d -p /home/cole/Projects/titonium
```

Useful IPC calls:

```bash
qs -p /home/cole/Projects/titonium ipc call app status
qs -p /home/cole/Projects/titonium ipc call spotlight toggle
qs -p /home/cole/Projects/titonium ipc call spotlight clipboard
qs -p /home/cole/Projects/titonium ipc call spotlight close
```

Read [AGENTS.md](AGENTS.md) before adding or adapting a module.
