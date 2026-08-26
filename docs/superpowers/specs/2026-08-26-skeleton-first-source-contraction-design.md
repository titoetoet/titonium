# Titonium Skeleton-First Source Contraction

**Date:** 2026-08-26
**Status:** Awaiting written-spec review

## Purpose

Contract the current greenfield implementation into a small, usable Quickshell skeleton before
researching and importing modules from external ricing repositories. The contraction happens
in-place in `/home/cole/Projects/titonium`; it does not create another project, branch or permanent
compatibility tree.

The result must remain a working daily shell throughout the migration. Spotlight and Input Method
are protected product features. Workspaces and Clock remain visible as replaceable convenience
widgets until better modules are selected.

## Chosen approach

Use an **in-place staged contraction**. First lock the protected behavior with tests, then introduce
the smaller skeleton composition, route the live shell through it, and only then delete unreachable
source. Git history is the rollback mechanism.

Rejected approaches:

- A second project or long-lived branch would prevent the live `/home/cole/Projects/titonium`
  instance from being the source of truth.
- A hard delete followed by reconstruction would unnecessarily break Spotlight keybindings and
  make regressions harder to localize.
- Keeping a broad compatibility facade would preserve the same accidental architecture under new
  folder names.

## Protected behavior

### Spotlight

Preserve the current Applications, Clipboard and mock System scopes, keyboard navigation,
calculator results, categorized 5×4 browsing, density indicators, application visibility,
desktop-entry discovery and safe application launch flow. Spotlight remains an overlay independent
of the MenuBar.

The live bindings remain byte-for-byte unchanged in both Hyprland configuration copies:

- `Super + Space` calls `spotlight toggle`.
- `Super + V` calls `spotlight clipboard`.

The IPC target and project path remain stable. Existing acceptance must prove both bindings' target
methods load before any obsolete source is removed.

### Input Method

Preserve the event-driven Fcitx StatusNotifier integration, label/icon semantics and lack of polling
or process ownership. Input Method remains visible in the minimal MenuBar.

### Skeleton primitives

Preserve behavior for:

- one reactive MenuBar surface per `Quickshell.screens` entry;
- runtime monitor add/remove without hardcoded output names;
- lazy transient content, focus, outside-click and focused-monitor fallback;
- semantic theme tokens with Neutral Utility as the safe solid baseline;
- locale fallback `vi -> en -> key`;
- application, clipboard, Hyprland and input platform integrations;
- runtime data outside the repository and atomic writes where persistence remains active;
- `qmllint`, architecture, foreground smoke and live IPC/log gates.

Implementation files are not protected merely because their behavior is. A smaller implementation
may replace `SurfaceCoordinator`, screen routing or configuration code only after the protected
acceptance remains green.

## Minimal live composition

After contraction the MenuBar contains only:

- Workspaces — retained temporarily as a replaceable, event-driven widget;
- Input Method — protected;
- Clock — retained temporarily as a replaceable convenience widget.

The Arch Menu, Active Window strip and diagnostic widgets leave the default layout. Spotlight has
no MenuBar trigger and remains accessible through its existing keybindings.

The Clock trigger must not retain Calendar or Lunar panel code merely to keep a text clock. The
first contraction may keep the existing Clock module intact while the new composition is proven;
the deletion stage must reduce it to the smallest dependency set needed by the visible clock.

## Target source shape

```text
Titonium/
├── App.qml
├── Core/
│   ├── Screens/
│   ├── Surfaces/
│   └── Runtime/
├── Services/
│   ├── Applications/
│   ├── Clipboard/
│   ├── Hyprland/
│   └── InputMethod/
├── Bar/
│   ├── BarHost.qml
│   ├── BarSurface.qml
│   └── widgets/
├── Overlays/
│   └── Spotlight/
├── Theme/
└── Shared/
```

Folder names describe ownership rather than enforcing layers for their own sake. Each imported
module later follows the smallest useful shape: a service for shared state, a widget for MenuBar
presentation and a panel only when it has transient content. Modules without one of those concerns
do not receive an empty stub.

QML module URIs remain under `Titonium.*`. Moves must use explicit `qmldir` entries, and the shell
must not depend on legacy import paths once deletion starts.

## State and presentation boundary

Views may render state and emit user intent. They must not instantiate `Process`, execute commands,
open raw compositor sockets, access DBus platform APIs directly or persist settings.

Services own Quickshell platform APIs and shared state. One service instance feeds every future
consumer such as Bar, Control Center and OSD. A service is introduced only when at least one live
feature needs it; no Wi-Fi, Bluetooth, MPRIS, audio or notification stubs are part of this
contraction.

The future external-module workflow is:

1. inspect license, Quickshell version and dependencies;
2. identify behavior and edge cases worth retaining;
3. port the smallest slice behind a Titonium service contract;
4. adapt its widget/panel to shared theme and surface lifecycle;
5. run static and live acceptance before importing another module;
6. record upstream provenance and local deviations.

## Replaceable and removable source

The following features are not protected and leave runtime composition during contraction:

- Arch Menu, About and session confirmation UI;
- Active Window widget and task strip;
- Settings Center and all Settings pages;
- Design Gallery and Frame;
- Calendar and Lunar presentation;
- recursive JSON node composition and diagnostic widgets;
- Hybrid Glass UI/editor and unused design controls.

Their directories are deleted only after a dependency scan proves they are unreachable from
`shell.qml`, the protected services and test tooling. Small pure assets with independent value,
such as the tested lunar conversion algorithm or session lifecycle fake, may be retained under an
explicit `archive/` documentation path only if they remain source-controlled reference and are not
imported by runtime. Otherwise Git history is sufficient and they are removed.

`ConfigStore`, theme catalog and shared controls are pruned by reachability rather than removed as
a group. Spotlight application visibility may retain the minimal settings/runtime machinery it
actually consumes. No future setting is added during contraction.

## Migration and rollback

Work proceeds in reversible commits:

1. baseline and strengthen protected acceptance;
2. add the skeleton composition without deleting current dependencies;
3. move Spotlight and its required services;
4. move Input Method and the temporary Workspaces/Clock widgets;
5. point `shell.qml` at the new composition and run live cutover;
6. remove unreachable modules, imports, schemas, translations, tests and documentation;
7. rewrite architecture and handoff documentation around Skeleton First / Modular Pluggable.

The currently running shell is stopped only after static gates pass. Foreground smoke runs before
daemon restart. If live Spotlight, Input Method, screen spawning or log acceptance fails, restart
the last green commit using the same project path. Neither Hyprland configuration file is edited
during this project.

## Testing and acceptance

Before and after every migration stage:

- `qmllint` has no errors; any Quickshell-only warning remains explicitly allowlisted;
- foreground smoke reaches `Configuration Loaded` without `ERROR`, `TypeError`, illegal method or
  unavailable type;
- adding/removing screens remains driven by `Quickshell.screens`, with one Bar per output and the
  correct exclusive zone;
- `Super + Space` opens Spotlight Applications on the focused screen;
- `Super + V` opens Clipboard mode on the focused screen;
- Tab scope cycling, search, Escape and outside-click lifecycle remain accepted;
- application discovery and visibility remain shared, and tests never launch a real application or
  write clipboard contents;
- Input Method updates from Fcitx events without a timer or process;
- Workspaces and Clock remain visible and usable, but their exact presentation is not protected;
- idle code contains no new polling timer, infinite animation, hidden heavy Loader tree or effect;
- both Hyprland configuration hashes remain unchanged;
- Git is clean after runtime testing.

Deletion acceptance additionally requires an import/reachability scan to show that no removed
module name, retired URI or obsolete settings key remains in runtime source, defaults, schemas,
translations, scripts or current documentation.

## Out of scope

- researching or selecting upstream ricing repositories;
- Wi-Fi, Bluetooth, audio, MPRIS, System Tray, notifications, Control Center or OSD;
- redesigning Spotlight or Input Method;
- new theme work, glass effects or animation systems;
- new Settings pages or migrations;
- changing Hyprland keybindings or compositor configuration.

Those items begin only after the contracted skeleton has been visually tested and accepted.
