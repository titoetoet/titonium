#!/usr/bin/env python3

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SETTINGS = ROOT / "Titonium/Settings"
APP = ROOT / "Titonium/App.qml"
ACCEPTANCE = ROOT / "scripts/settings_acceptance.sh"


def require(path: Path, fragments: tuple[str, ...], errors: list[str]) -> str:
    if not path.is_file():
        errors.append(f"missing {path.relative_to(ROOT)}")
        return ""
    source = path.read_text(encoding="utf-8")
    for fragment in fragments:
        if fragment not in source:
            errors.append(f"{path.name} missing contract: {fragment}")
    return source


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


def ipc_block(source: str, target: str) -> str:
    for match in re.finditer(r"\bIpcHandler\s*\{", source):
        block = qml_block(source, match.start())
        if re.search(rf'\btarget\s*:\s*"{re.escape(target)}"', block):
            return block
    return ""


def main() -> int:
    errors: list[str] = []
    coordinator = require(SETTINGS / "SettingsCoordinator.qml", (
        "pragma Singleton", "property string ownerScreenName:",
        "property string requestedPage:", "property bool discardConfirmationVisible:",
        "readonly property bool active:", "function open(screenName: string, pageId: string): bool",
        "function requestPage(pageId: string): bool", "function requestClose(): bool",
        "function discardAndClose(): bool", "function forceCancelAndClose(): bool",
        "function apply(): bool", "Preferences.beginPreview()", "Preferences.cancel()",
    ), errors)
    host = require(SETTINGS / "SettingsHost.qml", (
        "Variants {", "model: ScreenPolicy.screens", "SettingsWindow {",
    ), errors)
    window = require(SETTINGS / "SettingsWindow.qml", (
        "PanelWindow {", "implicitWidth: 980", "implicitHeight: 700",
        'WlrLayershell.namespace: "titonium-settings"',
        "WlrLayershell.exclusionMode: ExclusionMode.Ignore",
        "WlrLayershell.keyboardFocus:", "WlrKeyboardFocus.Exclusive",
        "Loader {", "active: window.ownsSettings", "Region { item: settingsLoader }",
    ), errors)
    center = require(SETTINGS / "SettingsCenter.qml", (
        "SettingsWorkspace {", "Keys.onEscapePressed:",
    ), errors)
    workspace = require(SETTINGS / "SettingsWorkspace.qml", (
        "Layout.preferredHeight: 64", "Layout.preferredWidth: 208",
        "Loader {", "id: pageLoader", "active: SettingsCoordinator.active",
        "GeneralPage {", "sourceComponent: root.componentFor(SettingsCoordinator.requestedPage)",
        "Preferences.dirty && !Preferences.savePending",
        "SettingsCoordinator.discardAndClose()", "SettingsCoordinator.apply()",
        "SettingsCoordinator.requestClose()", "SettingsCoordinator.discardConfirmationVisible",
    ), errors)
    require(SETTINGS / "components/SettingRow.qml", (
        "property string title:", "property string description:", "default property alias content:",
    ), errors)
    general = require(SETTINGS / "pages/GeneralPage.qml", (
        'Preferences.patch("locale"', 'Preferences.patch("accessibility.reducedMotion"',
        "Shared.Select", "Shared.Toggle",
    ), errors)

    qmldir = require(SETTINGS / "qmldir", (
        "module qs.Titonium.Settings", "singleton SettingsCoordinator 1.0 SettingsCoordinator.qml",
        "SettingsHost 1.0 SettingsHost.qml",
    ), errors)
    if qmldir.count("singleton SettingsCoordinator") != 1:
        errors.append("Settings module must export exactly one coordinator singleton")

    sources = "\n".join(path.read_text(encoding="utf-8") for path in SETTINGS.rglob("*.qml")) \
        if SETTINGS.is_dir() else ""
    for forbidden in (
        "FileView", "Process", "Quickshell.Services", "Quickshell.Hyprland",
        "MultiEffect", "ShaderEffect", "Animation.Infinite", "hyprctl", "nmcli", "wpctl",
    ):
        if forbidden in sources:
            errors.append(f"Settings presentation has forbidden dependency: {forbidden}")

    app = APP.read_text(encoding="utf-8") if APP.is_file() else ""
    for fragment in (
        "import qs.Titonium.Settings", "function openSettings(requestedScreen: var, pageId: string): string",
        "SettingsHost {}", "SettingsCoordinator.forceCancelAndClose()",
    ):
        if fragment not in app:
            errors.append(f"App missing Settings composition contract: {fragment}")
    if app.count("SettingsHost {}") != 1:
        errors.append("App must compose exactly one SettingsHost")
    ipc = ipc_block(app, "settings")
    if not ipc:
        errors.append("App must expose Settings lifecycle IPC")
    else:
        methods = set(re.findall(r"^\s*function\s+(\w+)\s*\(", ipc, re.MULTILINE))
        if methods != {"open", "page", "cancel", "state"}:
            errors.append(f"Settings IPC methods must be lifecycle-only, got {sorted(methods)}")
        for forbidden in ("patch", "apply", "restore", "FileView", "setText"):
            if forbidden in ipc.lower():
                errors.append(f"Settings IPC exposes forbidden mutation seam: {forbidden}")

    keys = (
        "settings.title", "settings.preview_hint", "settings.unsaved", "settings.saving",
        "settings.close", "settings.cancel", "settings.apply", "settings.discard.title",
        "settings.discard.body", "settings.discard.continue", "settings.discard.confirm",
        "settings.nav.general", "settings.general.title", "settings.general.description",
        "settings.general.language", "settings.general.reduced_motion",
        "settings.general.reduced_motion.description",
    )
    for locale in ("en", "vi"):
        path = ROOT / f"config/i18n/{locale}.json"
        catalog = json.loads(path.read_text(encoding="utf-8")).get("strings", {})
        for key in keys:
            if not isinstance(catalog.get(key), str) or not catalog[key]:
                errors.append(f"{locale} catalog missing Settings key: {key}")

    if errors:
        print("\n".join("FAIL " + error for error in errors))
        return 1
    acceptance = require(ACCEPTANCE, (
        "XDG_DATA_HOME=", "XDG_STATE_HOME=", "XDG_CACHE_HOME=",
        "trap cleanup EXIT", "hyprctl -j layers", "DP-1", "DP-3",
        "runtime_rejection_pattern", "before_git=", "before_live=", "before_dotfiles=",
        "settings open general", "settings page dock", "settings cancel",
    ), errors)
    for forbidden in (
        "settings apply", "settings patch", "settings restore",
    ):
        if forbidden in acceptance:
            errors.append(f"Settings acceptance exposes forbidden mutation IPC: {forbidden}")
    if errors:
        print("\n".join("FAIL " + error for error in errors))
        return 1
    print("PASS lazy Settings shell, General page and lifecycle acceptance contracts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
