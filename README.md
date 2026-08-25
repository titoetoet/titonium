# Titonium

Titonium is a modular Quickshell desktop shell for Hyprland. This repository is a greenfield
rewrite focused on predictable extension points, low idle cost and safe takeover by another
human or coding agent.

Milestone 0 provides a schema-driven, multi-monitor MenuBar foundation. The immutable
`titonium-neutral` baseline and lazy Design Gallery are complete. Milestone 1 now includes the
first production MenuBar slices: Workspaces, Active Window, event-driven Fcitx Input Method,
and a minute-precision Clock with a lazy Vietnamese lunar Calendar.
Settings Center, Spotlight, Window Switcher and notifications remain phased.

## Run

```bash
qs -n -p "$HOME/Projects/titonium"
```

Run the checks first:

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/runtime_acceptance.sh
```

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

Start with [AGENTS.md](AGENTS.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
