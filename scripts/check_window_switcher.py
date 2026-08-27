#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ROOT = ROOT / "Titonium/Services/WindowSwitcher"
OVERLAY_ROOT = ROOT / "Titonium/Overlays/WindowSwitcher"
SERVICE = SERVICE_ROOT / "WindowSwitcherService.qml"
RULES = SERVICE_ROOT / "WindowSwitcherRules.js"
SERVICE_QMLDIR = SERVICE_ROOT / "qmldir"
SURFACE = OVERLAY_ROOT / "WindowSwitcherSurface.qml"
TILE = OVERLAY_ROOT / "WindowSwitcherTile.qml"
OVERLAY_QMLDIR = OVERLAY_ROOT / "qmldir"
APP = ROOT / "Titonium/App.qml"
CHECK_SH = ROOT / "scripts/check.sh"
ACCEPTANCE = ROOT / "scripts/window_switcher_acceptance.sh"
HYPR_CONFIGS = (
    Path("/home/cole/.config/hypr/hyprland.lua"),
    Path("/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"),
)


def required(path: Path, fragments: tuple[str, ...], errors: list[str]) -> str:
    if not path.is_file():
        errors.append(f"missing {path.relative_to(ROOT)}")
        return ""
    source = path.read_text(encoding="utf-8")
    for fragment in fragments:
        if fragment not in source:
            errors.append(f"{path.relative_to(ROOT)} missing contract: {fragment}")
    return source


def main() -> int:
    errors: list[str] = []
    if not RULES.is_file():
        errors.append("missing Titonium/Services/WindowSwitcher/WindowSwitcherRules.js")

    service = required(SERVICE, (
        "pragma Singleton",
        "import qs.Titonium.Core.Screens",
        "import qs.Titonium.Core.Surfaces",
        "import qs.Titonium.Services.Hyprland",
        'import "WindowSwitcherRules.js" as WindowSwitcherRules',
        "readonly property bool active",
        "readonly property var windows",
        "property string selectedId",
        "property var recentIds",
        "function begin(direction: string): bool",
        "function next(): bool",
        "function previous(): bool",
        "function accept(): bool",
        "function cancel(): bool",
        "function select(id: string): bool",
        "function snapshot(): string",
        "HyprlandService.windows",
        "HyprlandService.activateWindow",
        "WindowSwitcherRules.mruIds",
        "WindowSwitcherRules.orderedWindows",
        "WindowSwitcherRules.reconcileSelection",
        "SurfaceManager.open",
        "SurfaceManager.close",
        "ScreenRouter.screenForName",
        'Qt.resolvedUrl("../../Overlays/WindowSwitcher/WindowSwitcherSurface.qml")',
        '"keyboardFocus": "exclusive"',
        '"closeOnMonitorChange": true',
        "target: HyprlandService",
        "function onWindowsChanged",
    ), errors)
    for forbidden in (
        "import Quickshell.Hyprland", "Hyprland.toplevels", "wayland", "toplevel",
        "selectedWindow", "selectedToplevel", "Process", "FileView", "execDetached",
        "hyprctl", "Timer {", "MultiEffect", "ShaderEffect",
    ):
        if forbidden in service:
            errors.append(f"Window Switcher service has forbidden dependency/state: {forbidden}")

    surface = required(SURFACE, (
        "FocusScope {",
        "import qs.Titonium.Services.WindowSwitcher",
        "WindowSwitcherService.windows",
        "WindowSwitcherTile",
        "orientation: ListView.Horizontal",
        "WindowSwitcherService.cancel()",
        "Keys.onEscapePressed",
        "Qt.Key_Return",
        "Qt.Key_Enter",
        "WindowSwitcherService.accept()",
        "forceActiveFocus",
        "TapHandler",
    ), errors)
    tile = required(TILE, (
        "required property var window",
        "Shared.SystemIcon",
        "root.window?.icon",
        "root.window?.title",
        "WindowSwitcherService.select(root.window.id)",
        "WindowSwitcherService.accept()",
        "HoverHandler",
        "TapHandler",
        "Theme.surface",
    ), errors)

    for path, source in ((SURFACE, surface), (TILE, tile)):
        for forbidden in (
            "Process", "FileView", "execDetached", "hyprctl", "Timer {", "MultiEffect",
            "ShaderEffect", "ToplevelManager", "Hyprland.toplevels", ".wayland",
            "Screencopy", "LiveCapture", "gradient:",
        ):
            if forbidden in source:
                errors.append(f"{path.relative_to(ROOT)} has forbidden dependency/effect: {forbidden}")

    if service and len(re.findall(r"property\s+(?:var|string)\s+selected\w*", service)) != 1:
        errors.append("Window Switcher must store only selectedId as selection state")
    if service and "selectedId: root.selectedId" not in service:
        errors.append("Window Switcher snapshot must expose selectedId, not a native object")

    if not SERVICE_QMLDIR.is_file() or (
            "singleton WindowSwitcherService 1.0 WindowSwitcherService.qml"
            not in SERVICE_QMLDIR.read_text(encoding="utf-8")):
        errors.append("Window Switcher service qmldir must export its singleton")
    if not OVERLAY_QMLDIR.is_file():
        errors.append("missing Titonium/Overlays/WindowSwitcher/qmldir")
    else:
        qmldir = OVERLAY_QMLDIR.read_text(encoding="utf-8")
        for fragment in (
            "module qs.Titonium.Overlays.WindowSwitcher",
            "WindowSwitcherSurface 1.0 WindowSwitcherSurface.qml",
            "WindowSwitcherTile 1.0 WindowSwitcherTile.qml",
        ):
            if fragment not in qmldir:
                errors.append(f"Window Switcher overlay qmldir missing: {fragment}")

    app = APP.read_text(encoding="utf-8") if APP.is_file() else ""
    for fragment in (
        "import qs.Titonium.Services.WindowSwitcher",
        'target: "window-switcher"',
        "WindowSwitcherService.next()",
        "WindowSwitcherService.previous()",
        "WindowSwitcherService.accept()",
        "WindowSwitcherService.cancel()",
        "WindowSwitcherService.snapshot()",
    ):
        if fragment not in app:
            errors.append(f"App missing Window Switcher integration: {fragment}")

    check_sh = CHECK_SH.read_text(encoding="utf-8") if CHECK_SH.is_file() else ""
    for fragment in (
        "node \"$project_root/scripts/check_windows.js\"",
        "node \"$project_root/scripts/check_window_switcher_rules.js\"",
        "python3 \"$project_root/scripts/check_window_switcher.py\"",
        "bash -n \"$project_root/scripts/window_switcher_acceptance.sh\"",
    ):
        if fragment not in check_sh:
            errors.append(f"missing Window Switcher check registration: {fragment}")
    if not ACCEPTANCE.is_file():
        errors.append("missing scripts/window_switcher_acceptance.sh")

    direct_path = "qs -p /home/cole/Projects/titonium ipc call window-switcher"
    for config in HYPR_CONFIGS:
        value = config.read_text(encoding="utf-8") if config.is_file() else ""
        if value.count(direct_path) < 3:
            errors.append(f"{config} missing direct Window Switcher bindings")
        if "qs -c titonium ipc call window-switcher" in value:
            errors.append(f"{config} retains stale Window Switcher command")
        if 'hl.dsp.submap("switcher")' in value or 'hl.define_submap("switcher"' in value:
            errors.append(f"{config} retains legacy Window Switcher submap")

    if errors:
        for error in errors:
            print(f"FAIL {error}")
        return 1
    print("PASS Window Switcher model, lifecycle, presentation, and architecture fixtures")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
