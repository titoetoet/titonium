# AGENTS.md — Titonium

This repository uses a **Skeleton First, Modular Pluggable** workflow. Preserve the small shell
core, study external implementations one capability at a time, then adapt only the useful logic
behind Titonium-owned contracts. Do not rebuild a generic framework in anticipation of features.

## Protected baseline

- Spotlight in `Titonium/Overlays/Spotlight` and its `Super + Space` / `Super + V` bindings.
- Input Method in `Titonium/Services/InputMethod` and `Titonium/Bar/widgets/InputMethod.qml`.
- Dynamic screen lifecycle in `Titonium/Bar/BarHost.qml` and the lazy overlay lifecycle.
- Runtime data outside Git. Never edit either `hyprland.lua` from a feature or theme.

Workspaces and Clock are temporary visible widgets and may be replaced after an explicit
reference-repo review. Protected features may be refactored only with equivalent acceptance
coverage and user approval.

## Dependency rules

- `App` composes `Bar`, `Core/Surfaces` and feature overlays.
- UI in `Bar`, `Overlays` and `Shared` reads services; it never owns `Process`, `FileView`, raw
  commands or persistence.
- `Services` own Quickshell/Hyprland/SystemTray/DesktopEntry/Clipboard integration and shared state.
- `Core` owns screen routing, surface lifecycle, preferences, i18n and logging.
- `Theme` is a static semantic token layer; `Shared` is the small reusable presentation layer.
- Services never import feature views. Feature slices do not import one another.

Every QML directory has a `qmldir` and imports use `qs.Titonium.*`. User-facing strings use
`I18n.tr()`. New runtime listeners are shared in a singleton service, not duplicated in widgets.

## Module workflow

1. Define the user behavior and a narrow service/view contract.
2. Research and record candidate repositories, licenses, versions and exact source files.
3. Add a failing domain or contract test.
4. Adapt logic into `Services/<Capability>` and presentation into its owning feature directory.
5. Add the minimum composition line; keep heavy surfaces behind `Loader.active`.
6. Run static, foreground and focused live acceptance before asking for visual review.

Copying an entire repo directory, retaining its global state object, or importing its theme system
is not allowed. Attribution and license notices must accompany adapted third-party code.

## Required gates

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
```

Never launch a real application or write clipboard contents in automated tests. Read
`docs/ARCHITECTURE.md`, `docs/MODULE_CONTRACT.md`, `docs/CODING_FLOW.md` and `docs/TESTING.md`
before implementation.
