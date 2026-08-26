# Titonium

Titonium is a modular Quickshell desktop shell for Hyprland. This repository is a greenfield
rewrite focused on predictable extension points, low idle cost and safe takeover by another
human or coding agent.

Milestone 0 provides a schema-driven, multi-monitor MenuBar foundation. The immutable
`titonium-neutral` baseline and lazy Design Gallery are complete. Milestone 1 now includes the
first production MenuBar slices: Workspaces, Active Window, event-driven Fcitx Input Method,
and a minute-precision Clock with a lazy analog panel. Spotlight discovers and executes desktop
entries through a dedicated Platform adapter, renders a fixed 5×4 browse grid with density-aware
page indicators and opens Clipboard history separately. Application visibility is a global
settings concern: hidden entries disappear from every Titonium picker but remain recoverable from
the Spotlight settings page. The Arch logo owns a compact system menu whose session actions replace
the menu with a dedicated screen-centered confirmation.
Settings Center provides transactional appearance, layout, frame, system, audio and Spotlight
pages with live global preview. Window Switcher and notifications remain phased.

## Run

```bash
qs -n -p "$HOME/Projects/titonium"
```

Run the checks first:

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/spotlight_acceptance.sh
./scripts/runtime_acceptance.sh
./scripts/settings_acceptance.sh
```

Open Settings on a named output and test a page directly:

```bash
qs -p /home/cole/Projects/titonium ipc call settings openPage theme DP-3
qs -p /home/cole/Projects/titonium ipc call settings openPage material DP-3
```

The Material page is visible only after selecting Titonium Hybrid Glass. Closing Settings,
pressing Escape or clicking outside cancels un-applied preview state; Apply writes atomic runtime
data outside the repository. Restore Appearance always returns to Neutral Utility dark/solid and
does not touch locale, layout, module settings or either `hyprland.lua` copy.

Open or close the Design Gallery without a Hyprland keybinding:

```bash
qs -p "$HOME/Projects/titonium" ipc call gallery toggle DP-3
qs -p "$HOME/Projects/titonium" ipc call gallery close
```

Open or close Calendar on a named output:

```bash
qs -p "$HOME/Projects/titonium" ipc call calendar toggle DP-3
qs -p "$HOME/Projects/titonium" ipc call calendar close
```

Open Spotlight Applications or Clipboard, or close the active Spotlight surface:

```bash
qs -p "$HOME/Projects/titonium" ipc call spotlight toggle
qs -p "$HOME/Projects/titonium" ipc call spotlight clipboard
qs -p "$HOME/Projects/titonium" ipc call spotlight close
```

Open or close the compact Arch Menu on a named output:

```bash
qs -p "$HOME/Projects/titonium" ipc call arch-menu toggle DP-3
qs -p "$HOME/Projects/titonium" ipc call arch-menu close
```

Automated acceptance may preview and cancel a session confirmation, but never confirms it:

```bash
qs -p "$HOME/Projects/titonium" ipc call arch-menu previewSessionAction lock
qs -p "$HOME/Projects/titonium" ipc call arch-menu close
```

Open a Settings page directly for testing:

```bash
qs -p "$HOME/Projects/titonium" ipc call settings openPage theme DP-3
qs -p "$HOME/Projects/titonium" ipc call settings openPage typography DP-3
qs -p "$HOME/Projects/titonium" ipc call settings openPage layout DP-3
qs -p "$HOME/Projects/titonium" ipc call settings openPage frame DP-3
qs -p "$HOME/Projects/titonium" ipc call settings close
```

Start with [AGENTS.md](AGENTS.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
