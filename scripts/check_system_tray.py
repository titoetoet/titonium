#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVICE_DIR = ROOT / "Titonium/Services/SystemTray"
SERVICE = SERVICE_DIR / "SystemTrayService.qml"
BACKEND = SERVICE_DIR / "internal/SystemTrayBackend.qml"
INTERNAL_QMLDIR = SERVICE_DIR / "internal/qmldir"
RULES = SERVICE_DIR / "SystemTrayRules.js"
QMLDIR = SERVICE_DIR / "qmldir"
INPUT_METHOD = ROOT / "Titonium/Services/InputMethod/InputMethodService.qml"
INPUT_VIEW = ROOT / "Titonium/Bar/widgets/InputMethod.qml"
ACTIVE_WINDOW = ROOT / "Titonium/Bar/islands/ActiveWindowPill.qml"
CHECK = ROOT / "scripts/check.sh"
POPUP_DIR = ROOT / "Titonium/Overlays/SystemTray"
MENU_VIEW = POPUP_DIR / "SystemTrayMenuView.qml"
POPUP_QMLDIR = POPUP_DIR / "qmldir"
RIGHT_COORDINATOR = ROOT / "Titonium/Bar/right/RightPillCoordinator.qml"


def main() -> int:
    errors: list[str] = []

    for path in (SERVICE, BACKEND, RULES, QMLDIR, INTERNAL_QMLDIR,
                 MENU_VIEW, POPUP_QMLDIR, RIGHT_COORDINATOR):
        if not path.is_file():
            errors.append(f"missing SystemTray capability file: {path.relative_to(ROOT)}")

    owners = []
    for path in (ROOT / "Titonium").rglob("*.qml"):
        if "import Quickshell.Services.SystemTray" in path.read_text(encoding="utf-8"):
            owners.append(path.relative_to(ROOT).as_posix())
    expected_owner = "Titonium/Services/SystemTray/internal/SystemTrayBackend.qml"
    if owners != [expected_owner]:
        errors.append(f"SystemTray must have one native owner, got: {owners}")

    if SERVICE.is_file():
        source = SERVICE.read_text(encoding="utf-8")
        for fragment in (
            "pragma Singleton",
            "Internal.SystemTrayBackend.descriptors",
            "Internal.SystemTrayBackend.inputMethod",
            "Internal.SystemTrayBackend.menuContextForApp",
            "Internal.SystemTrayBackend.popupEntries",
            "Internal.SystemTrayBackend.popupIsInputMethod",
            "Internal.SystemTrayBackend.prepareAppMenu",
            "Internal.SystemTrayBackend.prepareInputMenu",
            "readonly property var descriptors:",
            "readonly property var inputMethod:",
            "function contextForApp(appId: string, appName: string): string",
            "function menuContextForApp(appId: string, appName: string): string",
            "function selectApp(appId: string, appName: string): void",
            "function hasMenuForApp(appId: string, appName: string): bool",
            "readonly property var popupEntries:",
            "readonly property bool popupIsInputMethod:",
            "function inputMenuIcon(label: string): string",
            "readonly property bool popupCanGoBack:",
            "function prepareAppMenu(appId: string, appName: string): bool",
            "function prepareInputMenu(): bool",
            "function enterPopupEntry(index: int): bool",
            "function triggerPopupEntry(index: int): bool",
            "function popupBack(): bool",
        ):
            if fragment not in source:
                errors.append(f"SystemTrayService missing contract: {fragment}")
        for forbidden in ("Process {", "Timer {", "FileView {"):
            if forbidden in source:
                errors.append(f"SystemTrayService owns forbidden runtime behavior: {forbidden}")
        for leaked_native_property in (
            "readonly property var nativeItems:",
            "readonly property var selectedItem:",
            "readonly property QsMenuOpener selectedMenuOpener:",
        ):
            if leaked_native_property in source:
                errors.append(
                    f"SystemTrayService exposes native object: {leaked_native_property}")

    if QMLDIR.is_file():
        source = QMLDIR.read_text(encoding="utf-8")
        if "singleton SystemTrayService 1.0 SystemTrayService.qml" not in source:
            errors.append("SystemTray qmldir missing singleton export")
        if "SystemTrayBackend" in source:
            errors.append("SystemTray backend must not be exported from the public qmldir")

    if INTERNAL_QMLDIR.is_file():
        source = INTERNAL_QMLDIR.read_text(encoding="utf-8")
        if "singleton SystemTrayBackend 1.0 SystemTrayBackend.qml" not in source:
            errors.append("private SystemTray backend qmldir missing singleton declaration")

    input_source = INPUT_METHOD.read_text(encoding="utf-8")
    for fragment in (
        "import qs.Titonium.Services.SystemTray",
        "readonly property var item: SystemTrayService.inputMethod",
    ):
        if fragment not in input_source:
            errors.append(f"InputMethodService missing shared tray contract: {fragment}")
    if "Quickshell.Services.SystemTray" in input_source:
        errors.append("InputMethodService must not retain native SystemTray ownership")

    input_view = INPUT_VIEW.read_text(encoding="utf-8")
    for fragment in (
        "InputMethodService.vietnamese",
        "InputMethodService.english",
        "name: root.keyboardIcon",
        "acceptedButtons: Qt.LeftButton | Qt.RightButton",
        "RightPillCoordinator.toggleInput(root.screen.name, \"right\")",
    ):
        if fragment not in input_view:
            errors.append(f"Input icon lost protected presentation: {fragment}")

    active_source = ACTIVE_WINDOW.read_text(encoding="utf-8")
    for fragment in (
        "SystemTrayService.selectApp",
        "SystemTrayService.menuContextForApp",
        "SystemTrayService.hasMenuForApp",
        "RightPillCoordinator.toggleApp",
        'CenterSurfaceController.dispatch({ type: "request-open"',
    ):
        if fragment not in active_source:
            errors.append(f"ActiveWindowPill missing tray-menu contract: {fragment}")
    if "activeWindow?.title" not in active_source:
        errors.append("ActiveWindowPill must use compositor title only as non-tray fallback")
    if "selectedMenuAvailable" in active_source or "openSelectedMenu" in active_source or "openMenuForApp" in active_source:
        errors.append("ActiveWindowPill must not rely on mutable global tray selection at click time")

    if BACKEND.is_file() and ".display(" in BACKEND.read_text(encoding="utf-8"):
        errors.append("custom tray popup must not call native SystemTrayItem.display")
    if BACKEND.is_file():
        backend_source = BACKEND.read_text(encoding="utf-8")
        for fragment in ("property bool popupIsInputMethod: false",
                         "root.popupIsInputMethod = false",
                         "root.popupIsInputMethod = true"):
            if fragment not in backend_source:
                errors.append(f"SystemTray backend missing popup-kind contract: {fragment}")

    if RIGHT_COORDINATOR.is_file():
        source = RIGHT_COORDINATOR.read_text(encoding="utf-8")
        for fragment in ("toggleApp", "toggleInput", "prepareAppMenu", "prepareInputMenu"):
            if fragment not in source:
                errors.append(f"Right Pill coordinator missing: {fragment}")

    for obsolete in (POPUP_DIR / "SystemTrayPopupCoordinator.qml",
                     POPUP_DIR / "SystemTrayPopupSurface.qml"):
        if obsolete.exists():
            errors.append(f"detached popup boundary must be removed: {obsolete.relative_to(ROOT)}")

    if MENU_VIEW.is_file():
        source = MENU_VIEW.read_text(encoding="utf-8")
        for fragment in ("SystemTrayService.popupEntries", "enterPopupEntry",
                         "triggerPopupEntry", "popupBack",
                         "SystemTrayService.popupIsInputMethod",
                         "SystemTrayService.inputMenuPresentation(menuRow.modelData)",
                         'id: selectedCheckIcon',
                         'name: "check"',
                         "Accessible.CheckBox",
                         "Accessible.checkable:",
                         "Accessible.checked:"):
            if fragment not in source:
                errors.append(f"SystemTray popup surface missing: {fragment}")
        if 'visible: !SystemTrayService.popupIsInputMethod\n' not in source:
            errors.append("SystemTray popup must hide native icons for Input Method entries")
        if "&& !SystemTrayService.popupIsInputMethod" not in source:
            errors.append("Input Method selection must keep its popup open")
        if ('visible: !SystemTrayService.popupIsInputMethod\n'
                '                                && menuRow.modelData.buttonType !== "none"'
                not in source):
            errors.append("native app menus must retain their own check/radio indicators")
        label_index = source.find("? menuRow.inputPresentation.label")
        chevron_index = source.find('name: "chevron_right"')
        check_index = source.find("id: selectedCheckIcon")
        if not (0 <= label_index < chevron_index < check_index):
            errors.append(
                "Input Method selected check must be the final trailing element after label and chevron")
        for obsolete_header in ('name: "apps"', "SystemTrayService.popupTitle"):
            if obsolete_header in source:
                errors.append(
                    f"SystemTray popup must not retain its redundant first row: {obsolete_header}")
        for forbidden in ("Shared.Panel", "PanelWindow", "SurfaceManager",
                          "Quickshell.Services.SystemTray", "QsMenuOpener", "ChatGPT"):
            if forbidden in source:
                errors.append(f"shared SystemTray menu view owns forbidden boundary: {forbidden}")

    check_source = CHECK.read_text(encoding="utf-8")
    for fragment in (
        'node "$project_root/scripts/check_system_tray_rules.js"',
        'python3 "$project_root/scripts/check_system_tray.py"',
    ):
        if fragment not in check_source:
            errors.append(f"check.sh missing SystemTray gate: {fragment}")

    if errors:
        print("FAIL SystemTray shared ownership and StartIsland context")
        print("\n".join(errors))
        return 1
    print("PASS SystemTray shared ownership and StartIsland context")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
