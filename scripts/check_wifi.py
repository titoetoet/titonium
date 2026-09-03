#!/usr/bin/env python3

import os
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ROOT = ROOT / "Titonium/Services/Network"
OVERLAY_ROOT = ROOT / "Titonium/Overlays/Network"
SERVICE = SERVICE_ROOT / "NetworkService.qml"
PILL = ROOT / "Titonium/Bar/islands/ConnectivityPill.qml"
APP = ROOT / "Titonium/App.qml"
CHECK_SH = ROOT / "scripts/check.sh"
ACCEPTANCE = ROOT / "scripts/wifi_acceptance.sh"
REQUIRED = (
    "Titonium/Services/Network/WifiRules.js",
    "Titonium/Services/Network/NetworkService.qml",
    "Titonium/Services/Network/qmldir",
    "Titonium/Overlays/Network/NetworkPopupCoordinator.qml",
    "Titonium/Overlays/Network/NetworkPopupSurface.qml",
    "Titonium/Overlays/Network/ClassicNetworkPopupSurface.qml",
    "Titonium/Overlays/Network/WifiNetworkRow.qml",
    "Titonium/Overlays/Network/qmldir",
)
FORBIDDEN = ("Process", "FileView", "Timer", "nmcli", "execDetached", "psk:")


def source(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def qml_block(value: str, start: int) -> str:
    opening = value.find("{", start)
    if opening < 0:
        return ""
    depth = 0
    for index in range(opening, len(value)):
        if value[index] == "{":
            depth += 1
        elif value[index] == "}":
            depth -= 1
            if depth == 0:
                return value[start:index + 1]
    return ""


def function_block(value: str, name: str) -> str:
    match = re.search(rf"function\s+{re.escape(name)}\s*\(", value)
    return qml_block(value, match.start()) if match else ""


def native_import_errors() -> list[str]:
    importers = []
    for path in ROOT.rglob("*.qml"):
        if "import Quickshell.Networking" in source(path):
            importers.append(path.relative_to(ROOT))
    expected = [Path("Titonium/Services/Network/NetworkService.qml")]
    return [] if importers == expected else ["Quickshell.Networking must be imported only by NetworkService.qml"]


def service_errors(value: str) -> list[str]:
    errors = []
    required = (
        "pragma Singleton",
        "import Quickshell.Networking",
        'import "WifiRules.js" as WifiRules',
        "readonly property bool available:",
        "readonly property bool wifiEnabled:",
        "readonly property bool wifiHardwareEnabled:",
        "readonly property bool scanning:",
        "readonly property string connectedName:",
        "readonly property int connectedSignal:",
        "readonly property string iconName:",
        "readonly property var networks:",
        "readonly property string stateKey:",
        "function setWifiEnabled(value: bool): bool",
        "function setScanning(value: bool): bool",
        "function connect(id: string): bool",
        "function connectWithPassword(id: string, password: string): bool",
        "function disconnect(id: string): bool",
        "function forget(id: string): bool",
        "function snapshot(): string",
        "WifiRules.projectWifi",
        "WifiSecurityType.Open",
        "operationWarningLimit: 3",
    )
    for fragment in required:
        if fragment not in value:
            errors.append(f"missing Wi-Fi service contract: {fragment}")
    for fragment in FORBIDDEN:
        if fragment in value:
            errors.append(f"forbidden Wi-Fi service dependency or secret field: {fragment}")
    if "WifiSecurity.Open" in value:
        errors.append("Wi-Fi service uses the nonexistent WifiSecurity enum")
    if re.search(r"^\s*(?:readonly\s+)?property\s+\w+\s+password\s*:", value, re.MULTILINE):
        errors.append("Wi-Fi service must not retain a password property")
    for name, native_call in (("connect", ".connect()"),
                              ("connectWithPassword", ".connectWithPsk(password)"),
                              ("disconnect", ".disconnect()"),
                              ("forget", ".forget()")):
        block = function_block(value, name)
        if "Networking.devices.values" not in block or "return false" not in block:
            errors.append(f"Wi-Fi {name} must re-resolve a stale native network safely")
        if "WifiRules.preferredNativeForId" not in block:
            errors.append(f"Wi-Fi {name} must resolve duplicate SSIDs exactly as its projection does")
        if native_call not in block:
            errors.append(f"Wi-Fi {name} must use its native mutation method")
    if "JSON.stringify({" not in function_block(value, "snapshot"):
        errors.append("Wi-Fi snapshot must project a fresh serializable value")
    return errors


def presentation_errors() -> list[str]:
    errors = []
    coordinator = source(OVERLAY_ROOT / "NetworkPopupCoordinator.qml")
    popup = source(OVERLAY_ROOT / "NetworkPopupSurface.qml")
    classic_popup = source(OVERLAY_ROOT / "ClassicNetworkPopupSurface.qml")
    row = source(OVERLAY_ROOT / "WifiNetworkRow.qml")
    qmldir = source(OVERLAY_ROOT / "qmldir")
    pill = source(PILL)
    for fragment in (
        "pragma Singleton", "ScreenRouter", "SurfaceManager.open", "SurfaceManager.close",
        '"network:"', '"source": Qt.resolvedUrl("NetworkPopupSurface.qml")',
        '"keyboardFocus": "exclusive"', "function open(screen: var, invoker: var): bool",
        "function toggle(screen: var, invoker: var): bool", "function close(): bool",
    ):
        if fragment not in coordinator:
            errors.append(f"missing Wi-Fi coordinator contract: {fragment}")
    for fragment in (
        "import qs.Titonium.Services.Network", '"connected"', '"known"', '"available"',
        "onTriggered: NetworkService.setScanning(!NetworkService.scanning)",
        "WifiNetworkRow", "TapHandler", "Keys.onEscapePressed", "Component.onDestruction",
        "name: NetworkService.iconName",
    ):
        if fragment not in popup:
            errors.append(f"missing Wi-Fi popup contract: {fragment}")
    for forbidden in ("Quickshell.Networking", "Networking.", "Timer", "Process", "FileView", "MultiEffect", "ShaderEffect"):
        if forbidden in popup:
            errors.append(f"forbidden Wi-Fi popup dependency: {forbidden}")
    for fragment in (
        "property var descriptor:", "property var screen:", "Shared.Panel", "SurfaceManager.close",
        "Keys.onEscapePressed", "TapHandler {", "anchors.fill: parent",
        "readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing",
        "anchors.rightMargin: Metrics.barPadding", "width: 380", "WifiNetworkRow",
    ):
        if fragment not in classic_popup:
            errors.append(f"missing Classic Wi-Fi popup contract: {fragment}")
    for forbidden in ("Quickshell.Networking", "Networking.", "Process", "FileView"):
        if forbidden in classic_popup:
            errors.append(f"forbidden Classic Wi-Fi popup dependency: {forbidden}")
    for fragment in (
        "property var network:", "property string password:", "onNetworkChanged:",
        "NetworkService.connect", "NetworkService.connectWithPassword", "NetworkService.disconnect",
        "NetworkService.forget", "password = \"\"", "Shared.Toggle",
        "checked: root.network?.connected === true",
        "visible: root.network?.connected === true",
        "onToggled: checked =>",
        "name: root.network?.signalIcon || \"signal_wifi_0_bar\"",
        'name: "lock"',
        "visible: root.network?.secure === true",
    ):
        if fragment not in row:
            errors.append(f"missing Wi-Fi row contract: {fragment}")
    if "label: I18n.tr(root.primaryActionKey)" in row:
        errors.append("Wi-Fi connected state must use Toggle instead of a disconnect text button")
    if "property string password:" in popup:
        errors.append("Wi-Fi password must remain local to its row")
    if (("Component.onCompleted" in popup and "NetworkService.setScanning(true)" in popup)
            or ("Component.onDestruction" in popup and "NetworkService.setScanning(false)" in popup)):
        errors.append("Wi-Fi popup lifecycle must not mutate host scan state")
    if "module qs.Titonium.Overlays.Network" not in qmldir:
        errors.append("Wi-Fi overlay qmldir module name is missing")
    for export in ("singleton NetworkPopupCoordinator 1.0 NetworkPopupCoordinator.qml",
                   "NetworkPopupSurface 1.0 NetworkPopupSurface.qml",
                   "ClassicNetworkPopupSurface 1.0 ClassicNetworkPopupSurface.qml",
                   "WifiNetworkRow 1.0 WifiNetworkRow.qml"):
        if export not in qmldir:
            errors.append(f"Wi-Fi overlay qmldir export is missing: {export}")
    for fragment in (
        "import qs.Titonium.Overlays.Network", "import qs.Titonium.Services.Network",
        "NetworkPopupCoordinator.toggle(root.screen, networkButton)", "NetworkService.stateKey",
        "iconName: NetworkService.iconName", "enabled: NetworkService.available",
    ):
        if fragment not in pill:
            errors.append(f"missing Wi-Fi Bar-button contract: {fragment}")
    return errors


def integration_errors() -> list[str]:
    errors = []
    app = source(ROOT / "Titonium/Ipc/DeviceIpc.qml")
    check_sh = source(CHECK_SH)
    locales = [source(ROOT / "config/i18n/en.json"), source(ROOT / "config/i18n/vi.json")]
    for fragment in (
        "import qs.Titonium.Overlays.Network",
        "import qs.Titonium.Services.Network",
        'target: "network"',
        "NetworkService.snapshot()",
        "NetworkPopupCoordinator.openForIpc(screen)",
        "NetworkPopupCoordinator.close()",
    ):
        if fragment not in app:
            errors.append(f"missing Wi-Fi DeviceIpc integration: {fragment}")
    for fragment in (
        "node \"$project_root/scripts/check_wifi_rules.js\"",
        "python3 \"$project_root/scripts/check_wifi.py\"",
        "bash -n \"$project_root/scripts/wifi_acceptance.sh\"",
    ):
        if fragment not in check_sh:
            errors.append(f"missing Wi-Fi check registration: {fragment}")
    if not ACCEPTANCE.is_file():
        errors.append("missing scripts/wifi_acceptance.sh")
    required_keys = (
        '"wifi.title"', '"wifi.connected"', '"wifi.off"', '"wifi.on"',
        '"wifi.network.connect"', '"wifi.network.disconnect"',
        '"wifi.password.accessible"', '"wifi.section.available"',
        '"wifi.signal.excellent"', '"wifi.unavailable"',
    )
    for key in required_keys:
        if any(key not in locale for locale in locales):
            errors.append(f"missing Wi-Fi locale parity key: {key}")
    return errors


def main() -> int:
    errors = []
    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            errors.append(f"missing Wi-Fi file: {relative}")
    errors.extend(native_import_errors())
    errors.extend(service_errors(source(SERVICE)))
    errors.extend(presentation_errors())
    errors.extend(integration_errors())
    rules = subprocess.run(["node", str(ROOT / "scripts/check_wifi_rules.js")], cwd=ROOT,
                           text=True, capture_output=True, check=False)
    if rules.returncode:
        errors.append("Wi-Fi rules fixture failed: " + rules.stderr.strip().split("\n")[0])
    if errors:
        print("\n".join("FAIL " + error for error in errors))
        return 1
    print("PASS Wi-Fi service and presentation architecture")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
