#!/usr/bin/env python3
"""Guard Titonium's architectural boundaries with inexpensive static checks."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    errors: list[str] = []

    for qml_dir in sorted({path.parent for path in (root / "Titonium").rglob("*.qml")}):
        if not (qml_dir / "qmldir").is_file():
            errors.append(f"missing qmldir: {qml_dir.relative_to(root)}")

    forbidden_ui = re.compile(r"\b(Process|FileView)\s*\{")
    forbidden_commands = re.compile(r"\b(hyprctl|nmcli|wpctl)\b")
    forbidden_platform_imports = re.compile(
        r"^import Quickshell\.(Hyprland|Services\.SystemTray)\b", re.MULTILINE
    )
    forbidden_platform_objects = re.compile(r"\b(Hyprland|ToplevelManager|SystemTray)\.")
    forbidden_perf = re.compile(r"\b(MultiEffect|ShaderEffect)\b|Animation\.Infinite|loops\s*:\s*Animation\.Infinite")
    allowed_io = {"Foundation", "Platform"}

    for path in sorted((root / "Titonium").rglob("*.qml")):
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(root)
        layer = relative.parts[1] if len(relative.parts) > 1 else ""
        if layer not in allowed_io and forbidden_ui.search(text):
            errors.append(f"platform I/O in UI layer: {relative}")
        if layer not in allowed_io and forbidden_commands.search(text):
            errors.append(f"raw platform command in UI layer: {relative}")
        if layer != "Platform" and forbidden_platform_imports.search(text):
            errors.append(f"direct platform API import outside Platform: {relative}")
        if layer != "Platform" and forbidden_platform_objects.search(text):
            errors.append(f"direct platform object access outside Platform: {relative}")
        if layer != "Platform" and re.search(r"\bDesktopEntries\b", text):
            errors.append(f"direct desktop-entry access outside Platform: {relative}")
        if forbidden_perf.search(text):
            errors.append(f"forbidden always-on visual cost: {relative}")
        if "/home/" in text or "~/" in text:
            errors.append(f"hardcoded home path in QML: {relative}")
        if ".config/quickshell/titonium" in text or ".local/share/Trash/files/titonium" in text:
            errors.append(f"legacy source reference in runtime QML: {relative}")

    registry = (root / "Titonium/Composition/WidgetRegistry.qml").read_text(encoding="utf-8")
    if "unknownSource" not in registry or "sourceFor" not in registry:
        errors.append("WidgetRegistry must provide an unknown widget fallback")
    for widget_type in (
        "menubar.workspaces",
        "menubar.active-window",
        "menubar.input-method",
        "menubar.clock",
        "menubar.launcher",
    ):
        if widget_type not in registry:
            errors.append(f"WidgetRegistry is missing {widget_type}")

    overlay = (root / "Titonium/Surfaces/OverlayHost.qml").read_text(encoding="utf-8")
    if "Loader" not in overlay or "active:" not in overlay:
        errors.append("OverlayHost must lazy-load transient UI")
    if "implicitWidth: window.modelData.width" not in overlay or "implicitHeight: window.modelData.height" not in overlay:
        errors.append("OverlayHost must expose the target screen's logical size to lazy content")

    layout_renderer = (root / "Titonium/Composition/LayoutRenderer.qml").read_text(encoding="utf-8")
    if "Layout.preferredWidth: implicitWidth" not in layout_renderer:
        errors.append("LayoutRenderer must propagate asynchronously loaded widget width")
    if re.search(r"columns\s*:\s*[^\n?]+\?\s*0\b", layout_renderer):
        errors.append("LayoutRenderer horizontal columns must never resolve to zero")

    for adapter_path in (
        root / "Titonium/Platform/Hyprland/HyprlandAdapter.qml",
        root / "Titonium/Platform/Input/FcitxAdapter.qml",
    ):
        adapter_text = adapter_path.read_text(encoding="utf-8")
        if re.search(r"\b(Process|Timer)\s*\{", adapter_text):
            errors.append(f"MenuBar adapter must remain event-driven: {adapter_path.relative_to(root)}")

    clock_text = (root / "Titonium/Modules/MenuBar/Clock/ClockModel.qml").read_text(encoding="utf-8")
    if "SystemClock.Minutes" not in clock_text or "SystemClock.Seconds" in clock_text:
        errors.append("Clock must update by minute, never by second")
    clock_feature = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (root / "Titonium/Modules/MenuBar/Clock").glob("*.qml")
    )
    if re.search(r"\b(Timer|Process)\s*\{", clock_feature):
        errors.append("Clock and calendar must not poll or launch processes")

    launcher_feature = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (root / "Titonium/Modules/MenuBar/Launcher").glob("*.qml")
    )
    if re.search(r"\b(Timer|Process)\s*\{|execDetached|Animation\.Infinite", launcher_feature):
        errors.append("Launcher UI must not poll, spawn commands or animate continuously")
    application_adapter = (
        root / "Titonium/Platform/Applications/ApplicationCatalog.qml"
    ).read_text(encoding="utf-8")
    if "DesktopEntries.applications" not in application_adapter or "entry.execute()" not in application_adapter:
        errors.append("ApplicationCatalog must use Quickshell desktop-entry discovery and execution")

    accessibility_contracts = {
        "Button.qml": ("activeFocusOnTab:", "Accessible.role:", "Accessible.name:", "Accessible.focusable:"),
        "Card.qml": ("activeFocusOnTab:", "Accessible.role:", "Accessible.name:", "Accessible.focusable:"),
        "Switch.qml": ("activeFocusOnTab:", "Accessible.role:", "Accessible.name:", "Accessible.focusable:"),
        "Slider.qml": ("activeFocusOnTab:", "Accessible.role:", "Accessible.name:", "Accessible.focusable:"),
        "Dropdown.qml": ("activeFocusOnTab:", "Accessible.role:", "Accessible.name:", "Accessible.focusable:"),
        "Tabs.qml": ("activeFocusOnTab:", "Accessible.PageTabList", "Accessible.name:", "Accessible.focusable:"),
    }
    controls = root / "Titonium/Design/Controls"
    for filename, required_fragments in accessibility_contracts.items():
        text = (controls / filename).read_text(encoding="utf-8")
        for fragment in required_fragments:
            if fragment not in text:
                errors.append(f"missing accessibility contract {fragment!r}: Titonium/Design/Controls/{filename}")

    if errors:
        print("\n".join(f"FAIL {error}" for error in errors), file=sys.stderr)
        return 1
    print("PASS architecture boundaries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
