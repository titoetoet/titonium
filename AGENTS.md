# AGENTS.md — Titonium

This is the authoritative handoff for humans and coding agents working on Titonium, a
Quickshell desktop shell for Hyprland. Read this file, then the linked documents, before
changing code.

## Current milestone

Milestone 0 and Theme Foundation are complete. The active review slice is Design Controls,
ported in groups of two or three components. Typography, Icon and Button form the first
control batch; feature migration remains gated behind visual approval.

The legacy reference is read-only:

`~/.local/share/Trash/files/titonium`

The greenfield repository and runtime source is:

`~/Projects/titonium`

## Required reading

1. `docs/ARCHITECTURE.md` — dependency direction, runtime flow and surface lifecycle.
2. `docs/CODING_FLOW.md` — the required implementation workflow.
3. `docs/MODULE_CONTRACT.md` — layout nodes and widget contracts.
4. `docs/CONFIG_AND_MIGRATIONS.md` — persistence, validation and schema policy.
5. `docs/THEMING_AND_GLASS.md` — semantic theme and material backend contract.
6. `docs/PERFORMANCE.md` — idle-cost and lazy-loading rules.
7. `docs/TESTING.md` — checks that must pass before handoff.
8. `docs/ROADMAP.md` — phased feature order.

## Non-negotiable rules

- Dependency direction is `App/Surfaces -> Modules/Composition -> Design/Foundation -> Platform`.
- UI code must not instantiate `Process`, call `Quickshell.execDetached`, or write files.
- OS access belongs in `Titonium/Platform`; persistence belongs in `Foundation/ConfigStore.qml`.
- User-facing strings use `I18n.tr()` and semantic colors use `Theme.*`.
- Runtime data never lives in the repository. Defaults and schemas in `config/` are read-only.
- Every long-running timer, animation, poller or effect must be gated by an explicit consumer.
- Unknown configuration must degrade to a diagnostic component instead of crashing the shell.
- Every QML directory has a `qmldir`; Quickshell exposes the logical `Titonium.*`
  namespace at runtime as `qs.Titonium.*`.
- New settings are declared once in the schema/defaults and changed through `ConfigStore`.
- Never edit the legacy shell while implementing a greenfield milestone.
- The Neutral Utility package is always solid and must never invoke compositor integration.

## Definition of done

Run `scripts/check.sh`, then `scripts/smoke.sh`. A milestone is not done while static checks
fail, the foreground log contains QML errors, Hyprland reports config errors, or rollback is
undocumented.
