#!/usr/bin/env python3

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCK_ROOT = ROOT / "Titonium/Services/Dock"
PRESENTATION_ROOT = ROOT / "Titonium/Dock"
SERVICE = DOCK_ROOT / "DockService.qml"
RULES = DOCK_ROOT / "DockRules.js"
REGISTRY = DOCK_ROOT / "DockNativeRegistry.js"
QMLDIR = DOCK_ROOT / "qmldir"
REQUIRED_SERVICE_FRAGMENTS = (
    "pragma Singleton",
    "import Quickshell.Hyprland",
    "import qs.Titonium.Core.Runtime",
    "import qs.Titonium.Core.Screens",
    "import qs.Titonium.Services.Applications",
    "import qs.Titonium.Services.Dock",
    "readonly property var items",
    "readonly property int activeWorkspaceWindowCount",
    "import \"DockNativeRegistry.js\" as DockNativeRegistry",
    "property var operationRegistry: DockNativeRegistry.create()",
    "property var firstSeenIds",
    "function normalizedAppId",
    "function activateOrLaunch(appId: string): bool",
    "function launchNew(appId: string): bool",
    "function closeActive(appId: string): bool",
    "function togglePin(appId: string): bool",
    "function snapshot(): string",
    "Hyprland.toplevels.values",
    "ScreenPolicy.screens",
    "Hyprland.monitorFor(screen)",
    "ApplicationService.desktopEntryForAppId",
    "ApplicationService.iconForAppId",
    "ApplicationService.nameForAppId",
    "ApplicationService.launch(entry.id)",
    "DockRules.mergeItems",
    "DockStore.togglePin(appId)",
    "root.operationRegistry.replace(nativeById)",
    "function onRawEvent",
)
REQUIRED_MUTATION_RELOOKUPS = {
    "activateOrLaunch": "root.operationRegistry.activate",
    "launchNew": "root.entryForAppId(appId)",
    "closeActive": "root.operationRegistry.closeActive",
    "togglePin": "DockStore.togglePin(appId)",
}
FORBIDDEN_SERVICE_FRAGMENTS = (
    "Process",
    "FileView",
    "execDetached",
    "hyprctl",
    "Hyprland.dispatch",
    "Timer {",
    "qs.Titonium.Services.Bluetooth",
)
PUBLIC_FIELDS = ("appId", "name", "icon", "runningCount", "active", "urgent", "pinned")
APP = ROOT / "Titonium/App.qml"
DOCK_ACCEPTANCE = ROOT / "scripts/dock_acceptance.sh"


def ipc_handler_source(source: str, target: str) -> str:
    for match in re.finditer(r"\bIpcHandler\s*\{", source):
        block = qml_block(source, match.start())
        if re.search(rf'\btarget\s*:\s*"{re.escape(target)}"', block):
            return block
    return ""


def ipc_function_names(source: str) -> set[str]:
    return set(re.findall(r"^\s*function\s+(\w+)\s*\(", source, re.MULTILINE))


def locale_errors(prefix: str, required: dict[str, set[str]]) -> list[str]:
    errors = []
    catalogs = {}
    for locale in ("en", "vi"):
        path = ROOT / f"config/i18n/{locale}.json"
        try:
            catalogs[locale] = json.loads(path.read_text(encoding="utf-8")).get("strings", {})
        except (OSError, json.JSONDecodeError) as error:
            errors.append(f"cannot read {locale} locale: {error}")
            continue
        for key, placeholders in required.items():
            text = catalogs[locale].get(key)
            if not isinstance(text, str) or not text:
                errors.append(f"{locale} catalog missing {prefix} key: {key}")
                continue
            actual = set(re.findall(r"\{([^{}]+)\}", text))
            if actual != placeholders:
                errors.append(f"{locale} catalog has invalid placeholders for {key}")
    if len(catalogs) == 2 and set(catalogs["en"]) != set(catalogs["vi"]):
        errors.append(f"{prefix} locale keys are not identical")
    return errors


def validate_integration(errors: list[str]) -> None:
    if not APP.is_file():
        errors.append("missing App.qml for Dock integration")
        return
    source = APP.read_text(encoding="utf-8")
    if "import qs.Titonium.Dock" not in source:
        errors.append("App must import the Dock module")
    if len(re.findall(r"\bDockHost\s*\{", source)) != 1:
        errors.append("App must compose exactly one DockHost")
    dock_host = qml_block(source, source.find("DockHost")) if "DockHost" in source else ""
    if "onApplicationsRequested" not in dock_host or "root.openSpotlight(\"applications\", \"\", \"browse\", screen)" not in dock_host:
        errors.append("Dock Applications must route Spotlight Applications on the passed policy screen")
    spotlight = function_block(source, "openSpotlight")
    if "requestedScreen" not in spotlight or "ScreenRouter.screenForName(requestedScreen?.name" not in spotlight:
        errors.append("Spotlight must resolve a passed Dock screen through ScreenRouter")

    dock_ipc = ipc_handler_source(source, "dock")
    if not dock_ipc:
        errors.append("missing Dock IPC handler")
    elif ipc_function_names(dock_ipc) != {"state"} or "DockService.snapshot()" not in dock_ipc:
        errors.append("Dock IPC must expose only read-only state snapshot")

    if not DOCK_ACCEPTANCE.is_file():
        errors.append("missing dock read-only acceptance script")
    else:
        acceptance = DOCK_ACCEPTANCE.read_text(encoding="utf-8")
        calls = set(re.findall(r"\bcall_ipc\s+dock\s+(\w+)", acceptance))
        if calls != {"state"}:
            errors.append("Dock acceptance may call only dock state IPC")
        for fragment in ("qs -n -p", "hyprctl -j layers", "DP-1", "DP-3"):
            if fragment not in acceptance:
                errors.append(f"Dock acceptance missing read-only lifecycle check: {fragment}")
        if "runtime_rejection_pattern='\\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable'" not in acceptance:
            errors.append("Dock acceptance runtime rejection must use bounded error tokens")
    protected = ROOT / "scripts/protected_acceptance.sh"
    if protected.is_file() and "scripts/dock_acceptance.sh" not in protected.read_text(encoding="utf-8"):
        errors.append("protected acceptance must run Dock acceptance after Spotlight cleanup")
    dock_keys = {
        "dock.applications": set(),
        "dock.application_accessible": {"name", "count"},
        "dock.application_tooltip": {"name", "count"},
        "dock.menu.new_window": set(),
        "dock.menu.pin": set(),
        "dock.menu.unpin": set(),
        "dock.menu.close_active": set(),
        "dock.pin_control.open": set(),
        "dock.pin_control.close": set(),
    }
    errors.extend(locale_errors("Dock", dock_keys))


def validate_integration_gate_fixtures(errors: list[str]) -> None:
    mutation_ipc = """IpcHandler {
        target: \"dock\"
        function state(): string { return DockService.snapshot(); }
        function launch(appId: string): string { return \"mutated\"; }
    }"""
    if ipc_function_names(mutation_ipc) == {"state"}:
        errors.append("Dock IPC matcher missed a mutating fixture")

    bad_acceptance = "call_ipc dock activateOrLaunch app-id"
    if set(re.findall(r"\bcall_ipc\s+dock\s+(\w+)", bad_acceptance)) == {"state"}:
        errors.append("Dock acceptance matcher missed an intent fixture")


def validate_presentation(errors: list[str]) -> None:
    required_files = {
        "DockHost.qml": ("import qs.Titonium.Core.Screens", "model: ScreenPolicy.screens"),
        "DockWindow.qml": ("PanelWindow {", "titonium-dock", "mask: Region {",
            "WlrKeyboardFocus.None", "WlrLayer.Overlay", "ExclusionMode.Normal"),
        "DockSurface.qml": ("import qs.Titonium.Services.Dock", "DockAppButton", "itemMenu.active"),
        "DockAppButton.qml": ("DockService.activateOrLaunch", "DockService.launchNew",
            "QtControls.ToolTip", "size: root.iconSize"),
        "DockItemMenuCoordinator.qml": ("SurfaceManager.open", "DockItemMenuSurface.qml",
            "function menuItem(dockItem: var): var"),
        "DockItemMenuSurface.qml": ("SurfaceManager.close", "DockService.closeActive",
            "root.item?.runningCount > 0", "menuColumn.implicitHeight + menuPanel.padding * 2"),
        "qmldir": ("module qs.Titonium.Dock", "DockHost 1.0 DockHost.qml"),
    }
    for filename, fragments in required_files.items():
        path = PRESENTATION_ROOT / filename
        if not path.is_file():
            errors.append(f"missing Dock presentation file: {path.relative_to(ROOT)}")
            continue
        source = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in source:
                errors.append(f"Dock presentation missing contract: {filename}: {fragment}")
        for forbidden in ("Process", "FileView", "Timer {", "MultiEffect", "ShaderEffect", "hyprctl"):
            if forbidden in source:
                errors.append(f"Dock presentation has forbidden dependency: {filename}: {forbidden}")
    window = PRESENTATION_ROOT / "DockWindow.qml"
    if window.is_file() and "WlrLayershell.exclusionMode: ExclusionMode.Ignore" in window.read_text(encoding="utf-8"):
        errors.append("Dock pinned reservation must not use click-through exclusion mode")


def qml_block(source: str, start: int) -> str:
    opening = source.find("{", start)
    if opening < 0:
        return ""
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index + 1]
    return ""


def function_block(source: str, name: str) -> str:
    match = re.search(rf"function\s+{re.escape(name)}\s*\(", source)
    return qml_block(source, match.start()) if match else ""


def validate_native_owner(errors: list[str]) -> None:
    for path in DOCK_ROOT.rglob("*.qml"):
        source = path.read_text(encoding="utf-8")
        if "import Quickshell.Hyprland" in source and path != SERVICE:
            errors.append(f"Hyprland import outside DockService: {path.relative_to(ROOT)}")


def validate_rules_contract(errors: list[str]) -> None:
    if not RULES.is_file():
        errors.append("missing DockRules.js")
        return
    source = RULES.read_text(encoding="utf-8")
    item_match = re.search(r"function\s+itemFor\s*\(", source)
    item_source = qml_block(source, item_match.start()) if item_match else ""
    if not item_source:
        errors.append("DockRules must construct public item descriptors")
        return
    fields = re.findall(r"^\s*(\w+)\s*:", item_source, re.MULTILINE)
    if fields != list(PUBLIC_FIELDS):
        errors.append("Dock descriptors must contain exactly appId/name/icon/runningCount/active/urgent/pinned")
    if "toplevel" in item_source.lower() or "wayland" in item_source.lower():
        errors.append("Dock descriptor construction must not retain raw toplevel objects")


def validate_native_registry(errors: list[str]) -> None:
    if not REGISTRY.is_file():
        errors.append("missing DockNativeRegistry.js")
        return
    source = REGISTRY.read_text(encoding="utf-8")
    for fragment in ("function create()", "const nativeByAppId = {}", "function liveFor",
                     "activate: function", "closeActive: function"):
        if fragment not in source:
            errors.append(f"Dock native registry missing encapsulation contract: {fragment}")
    if "return nativeByAppId" in source or "getForAppId" in source:
        errors.append("Dock native registry must not expose raw toplevel objects")


def main() -> int:
    errors: list[str] = []
    if not SERVICE.is_file():
        errors.append("missing DockService.qml")
    else:
        source = SERVICE.read_text(encoding="utf-8")
        for fragment in REQUIRED_SERVICE_FRAGMENTS:
            if fragment not in source:
                errors.append(f"Dock service missing contract: {fragment}")
        for fragment in FORBIDDEN_SERVICE_FRAGMENTS:
            if fragment in source:
                errors.append(f"Dock service has forbidden dependency: {fragment}")
        for method, fragment in REQUIRED_MUTATION_RELOOKUPS.items():
            if fragment not in function_block(source, method):
                errors.append(f"Dock {method} must relookup its target before mutation")
        if "nativeToplevelsByAppId" in source or "nativeToplevelsForAppId" in source:
            errors.append("Dock service must not expose raw toplevel collections")
        if "Hyprland.focusedWorkspace" in source:
            errors.append("Dock workspace count must stay on the allowed DP-1 monitor")
        if "import Quickshell\n" in source:
            errors.append("Dock service must not retain an unused Quickshell import")
    if not QMLDIR.is_file() or "singleton DockService 1.0 DockService.qml" not in QMLDIR.read_text(encoding="utf-8"):
        errors.append("Dock qmldir must export DockService as a singleton")
    validate_native_owner(errors)
    validate_rules_contract(errors)
    validate_native_registry(errors)
    validate_presentation(errors)
    validate_integration(errors)
    validate_integration_gate_fixtures(errors)
    if errors:
        for error in errors:
            print(f"FAIL {error}")
        return 1
    print("PASS Dock native ownership and API fixtures")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
