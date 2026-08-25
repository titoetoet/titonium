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
    launcher_dir = root / "Titonium/Modules/MenuBar/Launcher"
    for launcher_file in (
        "ArchMenu.qml", "LauncherRail.qml", "LauncherSectionRegistry.qml",
        "AppsPage.qml", "PageIndicator.qml",
    ):
        if not (launcher_dir / launcher_file).is_file():
            errors.append(f"Arch Menu is missing focused component: {launcher_file}")
    launcher_widget_text = (launcher_dir / "LauncherWidget.qml").read_text(encoding="utf-8")
    if 'Qt.resolvedUrl("ArchMenu.qml")' not in launcher_widget_text:
        errors.append("Launcher trigger must open ArchMenu.qml")
    if re.search(r"\b(query|category|LauncherHistoryStore)\b", launcher_feature):
        errors.append("Arch Menu Apps must not contain search, categories or usage history")
    if (launcher_dir / "LauncherSectionRegistry.qml").is_file():
        registry_text = (launcher_dir / "LauncherSectionRegistry.qml").read_text(encoding="utf-8")
        if "sourceFor" not in registry_text or "AppsPage.qml" not in registry_text:
            errors.append("LauncherSectionRegistry must resolve Apps and provide sourceFor")
    if (launcher_dir / "ArchMenu.qml").is_file():
        arch_menu_text = (launcher_dir / "ArchMenu.qml").read_text(encoding="utf-8")
        if "Loader" not in arch_menu_text or "LauncherSectionRegistry.sourceFor" not in arch_menu_text:
            errors.append("Arch Menu must lazy-load sections through LauncherSectionRegistry")
    application_adapter = (
        root / "Titonium/Platform/Applications/ApplicationCatalog.qml"
    ).read_text(encoding="utf-8")
    if "DesktopEntries.applications" not in application_adapter or "entry.execute()" not in application_adapter:
        errors.append("ApplicationCatalog must use Quickshell desktop-entry discovery and execution")

    settings_feature = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (root / "Titonium/Modules/Settings").glob("*.qml")
    )
    if re.search(r"\b(Timer|Process|FileView)\s*\{|execDetached|MultiEffect|ShaderEffect", settings_feature):
        errors.append("Settings UI must remain transaction-only and effect-free")
    settings_workspace = root / "Titonium/Modules/Settings/SettingsWorkspace.qml"
    launcher_settings = root / "Titonium/Modules/MenuBar/Launcher/LauncherSettingsPage.qml"
    if not settings_workspace.is_file() or not launcher_settings.is_file():
        errors.append("Standalone and embedded Settings require a shared SettingsWorkspace")
    else:
        settings_center_text = (root / "Titonium/Modules/Settings/SettingsCenter.qml").read_text(encoding="utf-8")
        launcher_settings_text = launcher_settings.read_text(encoding="utf-8")
        if "SettingsWorkspace" not in settings_center_text or "SettingsWorkspace" not in launcher_settings_text:
            errors.append("Both Settings hosts must instantiate SettingsWorkspace")
        for host_name, host_text in (("SettingsCenter", settings_center_text), ("LauncherSettingsPage", launcher_settings_text)):
            if re.search(r"Component\s*\{\s*id:\s*(theme|typography|layout)PageComponent", host_text):
                errors.append(f"{host_name} must not duplicate Settings page components")
    launcher_widget_text = (root / "Titonium/Modules/MenuBar/Launcher/LauncherWidget.qml").read_text(encoding="utf-8")
    if '"cancelPreviewOnClose": true' not in launcher_widget_text:
        errors.append("Arch Menu descriptor must rollback abandoned Settings preview")
    power_page = root / "Titonium/Modules/MenuBar/Launcher/PowerPage.qml"
    if not power_page.is_file():
        errors.append("Arch Menu requires a lazy PowerPage")
    else:
        power_text = power_page.read_text(encoding="utf-8")
        if "pendingAction" not in power_text or "executeConfirmed" not in power_text:
            errors.append("PowerPage must require local confirmation before Platform execution")
        if re.search(r"\b(Process|systemctl|Hyprland\.)", power_text):
            errors.append("PowerPage must execute only through SessionActions")
    launcher_registry_path = root / "Titonium/Modules/MenuBar/Launcher/LauncherSectionRegistry.qml"
    if launcher_registry_path.is_file():
        launcher_registry_text = launcher_registry_path.read_text(encoding="utf-8")
        if not re.search(r'"id":\s*"power"[^\n]+"placement":\s*"bottom"', launcher_registry_text):
            errors.append("Power must be pinned to the bottom of the Launcher rail")
    launcher_rail_path = root / "Titonium/Modules/MenuBar/Launcher/LauncherRail.qml"
    if launcher_rail_path.is_file():
        launcher_rail_text = launcher_rail_path.read_text(encoding="utf-8")
        centered_primary_sections = re.search(
            r"Item\s*\{\s*Layout\.fillHeight:\s*true\s*\}"
            r"\s*Repeater\s*\{\s*model:\s*root\.sections\.filter\(section\s*=>\s*section\.placement\s*!==\s*\"bottom\"\)"
            r"[\s\S]*?Item\s*\{\s*Layout\.fillHeight:\s*true\s*\}"
            r"\s*Repeater\s*\{\s*model:\s*root\.sections\.filter\(section\s*=>\s*section\.placement\s*===\s*\"bottom\"\)",
            launcher_rail_text,
        )
        if not centered_primary_sections:
            errors.append("Apps and Settings must be vertically centered between flexible rail spacers")
    application_tile_path = root / "Titonium/Modules/MenuBar/Launcher/ApplicationTile.qml"
    if "anchors.centerIn: parent" not in application_tile_path.read_text(encoding="utf-8"):
        errors.append("Application icon and name group must be centered inside its tile")

    spotlight_dir = root / "Titonium/Modules/Spotlight"
    spotlight_files = (
        "SpotlightModel.qml",
        "SpotlightSurface.qml",
        "AppGrid.qml",
        "ApplicationTile.qml",
        "SearchResults.qml",
        "PageIndicator.qml",
        "qmldir",
    )
    for spotlight_file in spotlight_files:
        if not (spotlight_dir / spotlight_file).is_file():
            errors.append(f"Spotlight is missing focused component: {spotlight_file}")
    spotlight_qml = {
        path.name: path.read_text(encoding="utf-8")
        for path in spotlight_dir.glob("*.qml")
    }
    spotlight_feature = "\n".join(spotlight_qml.values())
    if re.search(
        r"\b(Process|FileView|Timer|MultiEffect|ShaderEffect)\s*\{|"
        r"execDetached|\b(hyprctl|nmcli|wpctl)\b|Animation\.Infinite|"
        r"loops\s*:\s*Animation\.Infinite",
        spotlight_feature,
    ):
        errors.append("Spotlight must not perform I/O, poll, spawn commands or animate continuously")
    spotlight_surface = spotlight_qml.get("SpotlightSurface.qml", "")
    if (
        "Loader" not in spotlight_surface
        or 'mode === "browse"' not in spotlight_surface
        or 'mode === "results"' not in spotlight_surface
        or "AppGrid.qml" not in spotlight_surface
        or "SearchResults.qml" not in spotlight_surface
    ):
        errors.append("SpotlightSurface must lazy-load browse and results branches")
    spotlight_accessibility = {
        "SpotlightSurface.qml": (
            "activeFocusOnTab:",
            "Accessible.name:",
            "Accessible.focusable:",
            "accessibleName: I18n.tr(\"spotlight.category_accessible\"",
        ),
        "ApplicationTile.qml": ("activeFocusOnTab:", "Accessible.name:", "Accessible.focusable:"),
        "SearchResults.qml": ("activeFocusOnTab:", "Accessible.name:", "Accessible.focusable:"),
    }
    for filename, required_fragments in spotlight_accessibility.items():
        text = spotlight_qml.get(filename, "")
        for fragment in required_fragments:
            if fragment not in text:
                errors.append(f"missing Spotlight accessibility contract {fragment!r}: {filename}")
    spotlight_results = spotlight_qml.get("SearchResults.qml", "")
    result_key_handler = re.search(
        r"Keys\.onPressed:\s*event\s*=>\s*\{"
        r"[\s\S]*?event\.key\s*===\s*Qt\.Key_Down"
        r"[\s\S]*?moveSelection\(1\)"
        r"[\s\S]*?event\.key\s*===\s*Qt\.Key_Up"
        r"[\s\S]*?moveSelection\(-1\)",
        spotlight_results,
    )
    if not result_key_handler:
        errors.append("Focused Spotlight result rows must forward Up/Down selection to SpotlightModel")

    coordinator_text = (root / "Titonium/Foundation/SurfaceCoordinator.qml").read_text(encoding="utf-8")
    if "cancelPreviewOnClose" not in coordinator_text or "ConfigStore.cancel()" not in coordinator_text:
        errors.append("SurfaceCoordinator must rollback abandoned preview transactions")

    config_store_text = (root / "Titonium/Foundation/ConfigStore.qml").read_text(encoding="utf-8")
    for contract in ("committedLayout", "previewLayout", "patchLayout", "restoreLayout", "runtimeLayoutFile.setText"):
        if contract not in config_store_text:
            errors.append(f"ConfigStore is missing layout transaction contract: {contract}")
    if ".concat(Validator.validateLayout(root.previewLayout))" not in config_store_text:
        errors.append("ConfigStore Apply must revalidate both transaction documents")

    material_text = (root / "Titonium/Design/MaterialSurface.qml").read_text(encoding="utf-8")
    if 'requested === "auto"' not in material_text or 'allowed.indexOf("qml")' not in material_text:
        errors.append("MaterialSurface must resolve auto/native through the QML fallback")
    surface_text = (root / "Titonium/Design/Controls/Surface.qml").read_text(encoding="utf-8")
    if 'backend: "solid"' in surface_text:
        errors.append("semantic Surface must not override the active theme material policy")
    catalog_text = (root / "Titonium/Foundation/ThemeCatalog.qml").read_text(encoding="utf-8")
    if "blockAllReads: true" not in catalog_text:
        errors.append("dynamic theme package reads must not return stale FileView content")

    capability_text = (root / "Titonium/Platform/Hyprland/HyprglassCapability.qml").read_text(encoding="utf-8")
    if '["hyprctl", "plugin", "list"]' not in capability_text or "running: true" not in capability_text:
        errors.append("hyprglass capability must use exactly one startup probe")
    if re.search(r"\bTimer\s*\{|restart|execDetached", capability_text):
        errors.append("hyprglass capability probe must never poll, mutate or retry")

    frame_feature = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (root / "Titonium/Modules/Frame").glob("*.qml")
    )
    if re.search(r"\b(Canvas|Timer|Process|MultiEffect|ShaderEffect)\s*\{", frame_feature):
        errors.append("Frame must remain geometry-only and event-driven")
    if "mask: Region {}" not in frame_feature or "FrameModel.enabled ? Quickshell.screens : []" not in frame_feature:
        errors.append("Frame must be click-through and absent while disabled")

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
