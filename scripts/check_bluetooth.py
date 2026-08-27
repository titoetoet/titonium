#!/usr/bin/env python3

import json
import os
import re
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BLUETOOTH_ROOT = ROOT / "Titonium/Services/Bluetooth"
SERVICE = BLUETOOTH_ROOT / "BluetoothService.qml"
REQUIRED_FILES = (
    "Titonium/Services/Bluetooth/BluetoothRules.js",
    "Titonium/Services/Bluetooth/BluetoothService.qml",
    "Titonium/Services/Bluetooth/qmldir",
)
PRESENTATION_ROOT = ROOT / "Titonium/Overlays/Bluetooth"
COORDINATOR = PRESENTATION_ROOT / "BluetoothPopupCoordinator.qml"
POPUP = PRESENTATION_ROOT / "BluetoothPopupSurface.qml"
DEVICE_ROW = PRESENTATION_ROOT / "BluetoothDeviceRow.qml"
CONNECTIVITY_PILL = ROOT / "Titonium/Bar/islands/ConnectivityPill.qml"
APP = ROOT / "Titonium/App.qml"
BLUETOOTH_ACCEPTANCE = ROOT / "scripts/bluetooth_acceptance.sh"
PRESENTATION_FILES = (
    "Titonium/Overlays/Bluetooth/BluetoothPopupCoordinator.qml",
    "Titonium/Overlays/Bluetooth/BluetoothPopupSurface.qml",
    "Titonium/Overlays/Bluetooth/BluetoothDeviceRow.qml",
    "Titonium/Overlays/Bluetooth/qmldir",
)
REQUIRED_FRAGMENTS = (
    "pragma Singleton",
    "import Quickshell.Bluetooth",
    "import \"BluetoothRules.js\" as BluetoothRules",
    "readonly property bool available:",
    "readonly property bool powered:",
    "readonly property bool discovering:",
    "readonly property string adapterName:",
    "readonly property int connectedCount:",
    "readonly property var devices:",
    "readonly property string stateKey:",
    "function setPowered(value: bool): bool",
    "function setDiscovering(value: bool): bool",
    "function connectDevice(address: string): bool",
    "function disconnectDevice(address: string): bool",
    "function pairDevice(address: string): bool",
    "function cancelPair(address: string): bool",
    "function forgetDevice(address: string): bool",
    "function snapshot(): string",
    "BluetoothRules.projectAdapter",
    "signal audioDeviceConnected(string address)",
    "function observeAudioConnections(): void",
    'Logger.info("bluetooth", "audio device connected " + event.connected[index])',
    'Logger.info("bluetooth", "audio device disconnected " + event.disconnected[index])',
    "adapter.discovering = false",
)
FORBIDDEN_FRAGMENTS = (
    "Process",
    "FileView",
    "Timer {",
    "DBus",
    "bluetoothctl",
    "rfkill",
    "systemctl",
    "execDetached",
)
MUTATION_METHODS = (
    "connectDevice",
    "disconnectDevice",
    "pairDevice",
    "cancelPair",
    "forgetDevice",
)
MUTATION_CALLS = {
    "connectDevice": ".connect()",
    "disconnectDevice": ".disconnect()",
    "pairDevice": ".pair()",
    "cancelPair": ".cancelPair()",
    "forgetDevice": ".forget()",
}
ROOT_PROPERTY = re.compile(
    r"^    (?:(?:readonly|required)\s+)?property\s+(.+?)\s*:", re.MULTILINE)
ROOT_MEMBER = re.compile(
    r"^    (?:(?:readonly|required)\s+)?property\s+.+?\s*:|^    function\s+\w+\s*\(",
    re.MULTILINE)
ROOT_FUNCTION = re.compile(r"^    function\s+(\w+)\s*\(", re.MULTILINE)
RAW_BLUETOOTH_REFERENCE = re.compile(
    r"\bBluetooth\b|\b\w+\s*\.\s*devices\b")
PUBLIC_PROPERTIES = {
    "projection", "available", "powered", "discovering", "adapterName", "connectedCount",
    "devices", "stateKey", "operationWarningLimit", "operationWarningCounts",
    "previousConnectedAudioAddresses",
}
PUBLIC_FUNCTIONS = {
    "warnOperation", "setPowered", "setDiscovering", "connectDevice", "disconnectDevice",
    "pairDevice", "cancelPair", "forgetDevice", "snapshot", "observeAudioConnections",
}


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


def ipc_handler_source(source: str, target: str) -> str:
    for match in re.finditer(r"\bIpcHandler\s*\{", source):
        block = qml_block(source, match.start())
        if re.search(rf'\btarget\s*:\s*"{re.escape(target)}"', block):
            return block
    return ""


def ipc_function_names(source: str) -> set[str]:
    return set(re.findall(r"^\s*function\s+(\w+)\s*\(", source, re.MULTILINE))


def bluetooth_locale_errors() -> list[str]:
    required = {
        "bluetooth.title": set(),
        "bluetooth.unavailable": set(),
        "bluetooth.off": set(),
        "bluetooth.on": set(),
        "bluetooth.scanning": set(),
        "bluetooth.connected": {"count"},
        "bluetooth.power.on.accessible": set(),
        "bluetooth.power.off.accessible": set(),
        "bluetooth.scan.start.accessible": set(),
        "bluetooth.scan.stop.accessible": set(),
        "bluetooth.section.connected": {"count"},
        "bluetooth.section.paired": {"count"},
        "bluetooth.section.available": {"count"},
        "bluetooth.section.accessible": {"name", "count", "collapsed"},
        "bluetooth.section.state.collapsed": set(),
        "bluetooth.section.state.expanded": set(),
        "bluetooth.devices.scanning": set(),
        "bluetooth.devices.empty": set(),
        "bluetooth.device.available": set(),
        "bluetooth.device.blocked": set(),
        "bluetooth.device.connecting": set(),
        "bluetooth.device.disconnecting": set(),
        "bluetooth.device.connected": set(),
        "bluetooth.device.pairing": set(),
        "bluetooth.device.paired": set(),
        "bluetooth.device.battery": {"percentage"},
        "bluetooth.device.connect": set(),
        "bluetooth.device.disconnect": set(),
        "bluetooth.device.pair": set(),
        "bluetooth.device.cancel_pair": set(),
        "bluetooth.device.action.accessible": {"action", "name"},
        "bluetooth.forget": set(),
        "bluetooth.forget.accessible": {"name"},
        "bluetooth.forget.confirm": set(),
        "bluetooth.forget.cancel": set(),
        "bluetooth.forget.confirm_action": set(),
        "menubar.connectivity.bluetooth.accessible": {"state", "count"},
    }
    errors = []
    catalogs = {}
    for locale in ("en", "vi"):
        path = ROOT / f"config/i18n/{locale}.json"
        try:
            strings = json.loads(path.read_text(encoding="utf-8")).get("strings", {})
        except (OSError, json.JSONDecodeError) as error:
            errors.append(f"cannot read {locale} Bluetooth catalog: {error}")
            continue
        catalogs[locale] = strings
        for key, placeholders in required.items():
            value = strings.get(key)
            if not isinstance(value, str) or not value:
                errors.append(f"{locale} catalog missing Bluetooth key: {key}")
                continue
            if set(re.findall(r"\{([^{}]+)\}", value)) != placeholders:
                errors.append(f"{locale} catalog has invalid placeholders for {key}")
    if len(catalogs) == 2 and set(catalogs["en"]) != set(catalogs["vi"]):
        errors.append("Bluetooth locale keys are not identical")
    return errors


def ipc_open_path_errors(coordinator: str) -> list[str]:
    block = function_block(coordinator, "openForIpc")
    if ("function openForIpc(screen: var): bool" not in coordinator
            or "ScreenRouter.screenForName(screen?.name" not in block
            or '"invoker": null' not in block
            or "SurfaceManager.open" not in block):
        return ["Bluetooth coordinator must provide explicit nullable-invoker IPC open path"]
    same_owner = re.search(
        r"if\s*\(\s*SurfaceManager\.ownerId\s*===\s*owner\s*\)\s*return\s+true\s*;", block)
    if not same_owner or same_owner.start() > block.find("SurfaceManager.open"):
        return ["Bluetooth IPC open must preserve an already-open owner descriptor and invoker"]
    return []


def section_accessible_errors(source: str) -> list[str]:
    if ("readonly property string sectionTitle:" not in source
            or "Accessible.name: section.sectionTitle" not in source
            or "Accessible.role: Accessible.Heading" not in source):
        return ["Bluetooth static section heading must expose its counted title"]
    return []


def root_property_blocks(source: str) -> list[tuple[str, str]]:
    members = list(ROOT_MEMBER.finditer(source))
    properties = []
    for match in ROOT_PROPERTY.finditer(source):
        declaration = match.group(1).strip()
        name = declaration.split()[-1]
        next_member = next((member.start() for member in members
                            if member.start() > match.start()), len(source))
        properties.append((name, source[match.start():next_member]))
    return properties


def public_native_exposure_errors(source: str) -> list[str]:
    errors = []
    for name, block in root_property_blocks(source):
        if name not in PUBLIC_PROPERTIES:
            errors.append(f"unexpected public Bluetooth singleton property: {name}")
            continue
        if block.lstrip().startswith("property alias"):
            errors.append(f"public alias may expose native Bluetooth state: {name}")
            continue
        if name == "projection":
            if "BluetoothRules.projectAdapter" not in block:
                errors.append("Bluetooth projection must normalize native state through BluetoothRules")
            if re.search(r"\breturn\s+(?:bluetooth|adapter|source)\b", block):
                errors.append("Bluetooth projection must not return native state")
            continue
        if name == "devices" and "root.projection.devices" in block:
            continue
        if RAW_BLUETOOTH_REFERENCE.search(block):
            errors.append(f"public singleton property exposes native Bluetooth state: {name}")
    for match in ROOT_FUNCTION.finditer(source):
        if match.group(1) not in PUBLIC_FUNCTIONS:
            errors.append(f"unexpected public Bluetooth singleton function: {match.group(1)}")
    return errors


def warning_cap_errors(source: str) -> list[str]:
    errors = []
    if "readonly property int operationWarningLimit: 3" not in source:
        errors.append("Bluetooth warning cap is missing")
    if "property var operationWarningCounts:" not in source:
        errors.append("Bluetooth warnings must be counted per category")
    block = function_block(source, "warnOperation")
    if ("category: string" not in block or "operationWarningCounts[category]" not in block
            or "operationWarningLimit" not in block):
        errors.append("Bluetooth warning cap must apply independently per category")
    return errors


def rules_check(path: Path | None = None) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    if path is not None:
        environment["TITONIUM_BLUETOOTH_RULES_PATH"] = str(path)
    return subprocess.run(["node", str(ROOT / "scripts/check_bluetooth_rules.js")],
                          cwd=ROOT, env=environment, text=True, capture_output=True, check=False)


def validate_gate_fixtures(errors: list[str]) -> None:
    bad_public_property = """QtObject {
    property var arbitraryAdapterAlias: Bluetooth.defaultAdapter
}"""
    bad_native_collection = """QtObject {
    property var unrelatedCollection: adapter.devices.values
}"""
    bad_alias = """QtObject {
    property alias unexpected: privateAdapter
}"""
    bad_module_property = """QtObject {
    property var publicModule: Bluetooth
}"""
    bad_native_function = """QtObject {
    function publicNativeDevice(): var { return Bluetooth.defaultAdapter; }
}"""
    for label, fixture in (("adapter property", bad_public_property),
                           ("device collection", bad_native_collection),
                           ("alias", bad_alias),
                           ("module property", bad_module_property),
                           ("native function", bad_native_function)):
        if not public_native_exposure_errors(fixture):
            errors.append(f"Bluetooth public-native matcher missed bad {label} fixture")

    bad_warning_cap = """QtObject {
    readonly property int operationWarningLimit: 3
    property int operationWarningCount: 0
    function warnOperation(message: string): void { operationWarningCount += 1; }
}"""
    if not warning_cap_errors(bad_warning_cap):
        errors.append("Bluetooth warning-cap matcher missed global-counter fixture")

    rules_source = (BLUETOOTH_ROOT / "BluetoothRules.js").read_text(encoding="utf-8")
    removed_field = "        blocked: device?.blocked === true,\n"
    if removed_field not in rules_source:
        errors.append("Bluetooth descriptor fixture cannot remove blocked field")
        return
    with tempfile.NamedTemporaryFile("w", suffix=".js", encoding="utf-8") as bad_rules:
        bad_rules.write(rules_source.replace(removed_field, ""))
        bad_rules.flush()
        if rules_check(Path(bad_rules.name)).returncode == 0:
            errors.append("Bluetooth rules fixture missed descriptor-field removal")


def validate_rules_contract(errors: list[str]) -> None:
    result = rules_check()
    if result.returncode != 0:
        errors.append("Bluetooth rules fixture failed: " + result.stderr.strip().split("\n")[0])


def validate_native_importer(errors: list[str]) -> None:
    importers = []
    for path in ROOT.rglob("*.qml"):
        if "import Quickshell.Bluetooth" in path.read_text(encoding="utf-8"):
            importers.append(path.relative_to(ROOT))
    expected = [Path("Titonium/Services/Bluetooth/BluetoothService.qml")]
    if importers != expected:
        errors.append("Quickshell.Bluetooth must be imported only by BluetoothService.qml")


def validate_service(errors: list[str]) -> None:
    if not SERVICE.is_file():
        return

    source = SERVICE.read_text(encoding="utf-8")
    for fragment in REQUIRED_FRAGMENTS:
        if fragment not in source:
            errors.append(f"missing Bluetooth service contract: {fragment}")
    for fragment in FORBIDDEN_FRAGMENTS:
        if fragment in source:
            errors.append(f"forbidden Bluetooth service dependency: {fragment}")

    errors.extend(public_native_exposure_errors(source))
    errors.extend(warning_cap_errors(source))

    for name in MUTATION_METHODS:
        block = function_block(source, name)
        if not block:
            errors.append(f"missing Bluetooth mutation method: {name}")
            continue
        if ("const nativeDeviceForAddress = function" not in block
                or "nativeDeviceForAddress(address)" not in block
                or "adapter.devices.values" not in block):
            errors.append(f"Bluetooth mutation must relookup its device: {name}")
        if "return false" not in block:
            errors.append(f"Bluetooth mutation must fail safely when stale: {name}")
        if MUTATION_CALLS[name] not in block:
            errors.append(f"Bluetooth mutation must use its native method: {name}")

    power_block = function_block(source, "setPowered")
    if "return false" not in power_block:
        errors.append("Bluetooth power mutation must fail safely when adapter is missing")


def validate_presentation(errors: list[str]) -> None:
    for relative in PRESENTATION_FILES:
        if not (ROOT / relative).is_file():
            errors.append(f"missing Bluetooth presentation file: {relative}")
    if not COORDINATOR.is_file() or not POPUP.is_file() or not DEVICE_ROW.is_file():
        return

    coordinator = COORDINATOR.read_text(encoding="utf-8")
    popup = POPUP.read_text(encoding="utf-8")
    row = DEVICE_ROW.read_text(encoding="utf-8")
    pill = CONNECTIVITY_PILL.read_text(encoding="utf-8") if CONNECTIVITY_PILL.is_file() else ""
    qmldir = (PRESENTATION_ROOT / "qmldir").read_text(encoding="utf-8") \
        if (PRESENTATION_ROOT / "qmldir").is_file() else ""

    coordinator_fragments = (
        "pragma Singleton",
        "import qs.Titonium.Core.Screens",
        "import qs.Titonium.Core.Surfaces",
        "readonly property bool active:",
        "function open(screen: var, invoker: var): bool",
        "function toggle(screen: var, invoker: var): bool",
        "function close(): bool",
        "ScreenRouter",
        '"bluetooth:"',
        '"source": Qt.resolvedUrl("BluetoothPopupSurface.qml")',
        '"keyboardFocus": "exclusive"',
        "SurfaceManager.open",
        "SurfaceManager.close",
    )
    for fragment in coordinator_fragments:
        if fragment not in coordinator:
            errors.append(f"missing Bluetooth popup coordinator contract: {fragment}")
    for forbidden in ("Loader", "PanelWindow", "Timer", "Process", "FileView", "Quickshell.Bluetooth"):
        if forbidden in coordinator:
            errors.append(f"forbidden Bluetooth coordinator dependency: {forbidden}")

    errors.extend(focus_return_errors(coordinator, popup))

    popup_fragments = (
        "import qs.Titonium.Services.Bluetooth",
        "readonly property real availableHeight:",
        "readonly property real contentHeight:",
        "height: Math.min(root.maximumHeight, root.availableHeight, root.contentHeight",
        "BluetoothService.adapterName",
        "BluetoothService.setPowered",
        "BluetoothService.setDiscovering",
        "Motion.normal",
        '"connected"',
        '"paired"',
        '"available"',
        "TapHandler",
        "Keys.onEscapePressed",
        "SurfaceManager.close",
        "Component.onCompleted: panel.forceActiveFocus",
        "readonly property string sectionTitle:",
        "Shared.TextLabel",
    )
    for fragment in popup_fragments:
        if fragment not in popup:
            errors.append(f"missing Bluetooth popup presentation contract: {fragment}")
    for forbidden in ("Quickshell.Bluetooth", "Bluetooth.defaultAdapter", "Loader", "PanelWindow",
                      "Timer", "Process", "FileView", "MultiEffect", "ShaderEffect"):
        if forbidden in popup:
            errors.append(f"forbidden Bluetooth popup dependency: {forbidden}")
    for forbidden in ("sectionCollapsed", "toggleSection", "expand_more", "expand_less"):
        if forbidden in popup:
            errors.append(f"Bluetooth device sections must be static, not dropdown controls: {forbidden}")

    row_fragments = (
        "import qs.Titonium.Services.Bluetooth",
        "property var device:",
        "I18n.tr(root.device?.stateKey",
        "batteryAvailable",
        "readonly property bool transitioning:",
        '"bluetooth.device.connecting"',
        '"bluetooth.device.disconnecting"',
        "BluetoothService.connectDevice",
        "BluetoothService.disconnectDevice",
        "BluetoothService.pairDevice",
        "BluetoothService.cancelPair",
        "BluetoothService.forgetDevice",
        "forgetConfirmation",
        "I18n.tr(\"bluetooth.forget.confirm\")",
        "I18n.tr(\"bluetooth.forget.cancel\")",
        "Shared.SystemIcon",
        "sourceName: root.device?.icon || \"bluetooth\"",
        "fallbackName: \"bluetooth\"",
    )
    for fragment in row_fragments:
        if fragment not in row:
            errors.append(f"missing Bluetooth device-row contract: {fragment}")
    for forbidden in ("Quickshell.Bluetooth", "Bluetooth.defaultAdapter", "Timer", "Process", "FileView",
                      "MultiEffect", "ShaderEffect"):
        if forbidden in row:
            errors.append(f"forbidden Bluetooth device-row dependency: {forbidden}")

    if "module qs.Titonium.Overlays.Bluetooth" not in qmldir:
        errors.append("Bluetooth overlay qmldir module name is missing")
    for export in ("singleton BluetoothPopupCoordinator 1.0 BluetoothPopupCoordinator.qml",
                   "BluetoothPopupSurface 1.0 BluetoothPopupSurface.qml",
                   "BluetoothDeviceRow 1.0 BluetoothDeviceRow.qml"):
        if export not in qmldir:
            errors.append(f"Bluetooth overlay qmldir export is missing: {export}")

    pill_fragments = (
        "import qs.Titonium.Overlays.Bluetooth",
        "import qs.Titonium.Services.Bluetooth",
        "BluetoothPopupCoordinator.toggle(root.screen, bluetoothButton)",
        "BluetoothService.stateKey",
        "BluetoothService.connectedCount",
        "bluetoothAccessibleName",
        "bluetoothIconName",
        "iconName: root.bluetoothIconName",
    )
    for fragment in pill_fragments:
        if fragment not in pill:
            errors.append(f"missing Bluetooth Bar-button contract: {fragment}")
    errors.extend(bluetooth_button_errors(pill))
    if "bluetooth_planned" in pill:
        errors.append("Bluetooth Bar button must replace the planned diagnostic glyph")
    for forbidden in ("Quickshell.Bluetooth", "Bluetooth.defaultAdapter", "Timer", "Process", "FileView"):
        if forbidden in pill:
            errors.append(f"forbidden Bluetooth Bar dependency: {forbidden}")


def focus_return_errors(coordinator: str, popup: str) -> list[str]:
    errors = []
    open_block = function_block(coordinator, "open")
    toggle_block = function_block(coordinator, "toggle")
    close_block = function_block(popup, "close")
    if ("invoker: var" not in open_block or "!invoker" not in open_block
            or '"invoker": invoker' not in open_block):
        errors.append("Bluetooth coordinator must require and pass its invoker")
    if "root.open(routedScreen, invoker)" not in toggle_block:
        errors.append("Bluetooth toggle must forward its invoker to open")
    if "readonly property var invoker:" not in popup:
        errors.append("Bluetooth popup must read its descriptor invoker")
    return_focus = function_block(popup, "returnFocus")
    if "root.invoker && root.invoker.forceActiveFocus" not in return_focus:
        errors.append("Bluetooth popup focus return must guard the invoker")
    if "root.returnFocus();" not in close_block:
        errors.append("Bluetooth popup close must return focus before closing")
    if "Component.onDestruction: root.returnFocus()" not in popup:
        errors.append("Bluetooth popup must return focus when destroyed")
    return errors


def bluetooth_button_errors(source: str) -> list[str]:
    errors = []
    if ("readonly property int diagnosticsWidth: networkButton.implicitWidth + bluetoothButton.implicitWidth"
            not in source):
        errors.append("Bluetooth diagnostics width must count exactly one button")
    button_start = source.find("id: bluetoothButton")
    button_block = qml_block(source, source.rfind("Shared.Button", 0, button_start)) \
        if button_start >= 0 else ""
    if "iconName: root.bluetoothIconName" not in button_block:
        errors.append("Bluetooth button must render its icon inside the control")
    if "anchors.centerIn: bluetoothButton" in source:
        errors.append("Bluetooth button must not have a sibling icon")
    return errors


def validate_presentation_gate_fixtures(errors: list[str]) -> None:
    missing_invoker_coordinator = """QtObject {
    function open(screen: var): bool { return true; }
    function toggle(screen: var): bool { return true; }
}"""
    valid_popup = """FocusScope {
    readonly property var invoker: descriptor?.invoker || null
    function returnFocus(): void { if (root.invoker && root.invoker.forceActiveFocus) root.invoker.forceActiveFocus(Qt.PopupFocusReason); }
    function close(): void { root.returnFocus(); SurfaceManager.close(ownerId); }
    Component.onDestruction: root.returnFocus()
}"""
    if not focus_return_errors(missing_invoker_coordinator, valid_popup):
        errors.append("Bluetooth focus-return matcher missed missing-invoker fixture")

    duplicate_icon_pill = """Item {
    readonly property int diagnosticsWidth: networkIcon.implicitWidth + bluetoothButton.implicitWidth
    Shared.Button { id: bluetoothButton; iconName: root.bluetoothIconName }
    Shared.Icon { anchors.centerIn: bluetoothButton }
}"""
    if not bluetooth_button_errors(duplicate_icon_pill):
        errors.append("Bluetooth button matcher missed sibling-icon fixture")


def validate_integration(errors: list[str]) -> None:
    coordinator = COORDINATOR.read_text(encoding="utf-8") if COORDINATOR.is_file() else ""
    errors.extend(ipc_open_path_errors(coordinator))

    row = DEVICE_ROW.read_text(encoding="utf-8") if DEVICE_ROW.is_file() else ""
    if ('label: I18n.tr(root.primaryActionKey)' not in row
            or 'I18n.tr("bluetooth.device.action.accessible", {' not in row
            or '"action": I18n.tr(root.primaryActionKey)' not in row
            or '"name": root.device?.name || ""' not in row):
        errors.append("Bluetooth row action must retain a plain label and expose action plus device name")

    popup = POPUP.read_text(encoding="utf-8") if POPUP.is_file() else ""
    errors.extend(section_accessible_errors(popup))

    pill = CONNECTIVITY_PILL.read_text(encoding="utf-8") if CONNECTIVITY_PILL.is_file() else ""
    connected_state = re.search(
        r'I18n\.tr\(BluetoothService\.stateKey\s*,\s*\{[^}]*"count"\s*:\s*BluetoothService\.connectedCount',
        pill, re.DOTALL)
    if not connected_state:
        errors.append("Bluetooth Bar accessibility state must pass connected count to translation")

    if not APP.is_file():
        errors.append("missing App.qml for Bluetooth integration")
    else:
        app = APP.read_text(encoding="utf-8")
        if "import qs.Titonium.Services.Bluetooth" not in app:
            errors.append("App must import BluetoothService for read-only state IPC")
        if "import qs.Titonium.Overlays.Bluetooth" not in app:
            errors.append("App must import Bluetooth popup coordinator")
        bluetooth_ipc = ipc_handler_source(app, "bluetooth")
        if not bluetooth_ipc:
            errors.append("missing Bluetooth IPC handler")
        elif ipc_function_names(bluetooth_ipc) != {"state", "popup", "closePopup", "popupState"}:
            errors.append("Bluetooth IPC must expose only state and popup lifecycle")
        elif ("BluetoothService.snapshot()" not in bluetooth_ipc
                or "BluetoothPopupCoordinator.openForIpc(screen)" not in bluetooth_ipc
                or "BluetoothPopupCoordinator.close()" not in bluetooth_ipc):
            errors.append("Bluetooth IPC must use only state and popup coordinator contracts")

    if not BLUETOOTH_ACCEPTANCE.is_file():
        errors.append("missing Bluetooth read-only acceptance script")
    else:
        acceptance = BLUETOOTH_ACCEPTANCE.read_text(encoding="utf-8")
        calls = set(re.findall(r"\bcall_ipc\s+bluetooth\s+(\w+)", acceptance))
        if not calls.issubset({"state", "popup", "closePopup", "popupState"}):
            errors.append("Bluetooth acceptance may call only state and popup IPC")
        if not {"state", "popup", "closePopup", "popupState"}.issubset(calls):
            errors.append("Bluetooth acceptance must cover all read-only popup IPC")
        for fragment in ("qs -n -p", "hyprctl -j layers", "DP-1", "DP-3"):
            if fragment not in acceptance:
                errors.append(f"Bluetooth acceptance missing read-only lifecycle check: {fragment}")
        if "runtime_rejection_pattern='\\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable'" not in acceptance:
            errors.append("Bluetooth acceptance runtime rejection must use bounded error tokens")
    protected = ROOT / "scripts/protected_acceptance.sh"
    if protected.is_file() and "scripts/bluetooth_acceptance.sh" not in protected.read_text(encoding="utf-8"):
        errors.append("protected acceptance must run Bluetooth acceptance after cleanup")
    errors.extend(bluetooth_locale_errors())


def validate_integration_gate_fixtures(errors: list[str]) -> None:
    mutating_ipc = """IpcHandler {
        target: \"bluetooth\"
        function state(): string { return BluetoothService.snapshot(); }
        function setPowered(value: bool): string { return \"mutated\"; }
    }"""
    if ipc_function_names(mutating_ipc) == {"state", "popup", "closePopup", "popupState"}:
        errors.append("Bluetooth IPC matcher missed a mutating fixture")

    coordinator_without_null = """QtObject {
        function openForIpc(screen: var): bool {
            return SurfaceManager.open(\"bluetooth:DP-1\", {}, screen);
        }
    }"""
    if not ipc_open_path_errors(coordinator_without_null):
        errors.append("Bluetooth IPC coordinator matcher missed non-nullable fixture")

    coordinator_reopens_existing = """QtObject {
        function openForIpc(screen: var): bool {
            const owner = \"bluetooth:DP-1\";
            return SurfaceManager.open(owner, { \"invoker\": null }, screen);
        }
    }"""
    if not ipc_open_path_errors(coordinator_reopens_existing):
        errors.append("Bluetooth IPC coordinator matcher missed same-owner reopen fixture")

    unresolved_section_accessible = """I18n.tr("bluetooth.section.accessible", {
        "name": I18n.tr("bluetooth.section." + section.modelData),
        "count": section.sectionDevices.length,
        "collapsed": root.sectionCollapsedFor(section.modelData)
    })"""
    if not section_accessible_errors(unresolved_section_accessible):
        errors.append("Bluetooth section accessibility matcher missed unresolved nested fixture")

    bad_acceptance = "call_ipc bluetooth setPowered true"
    if set(re.findall(r"\bcall_ipc\s+bluetooth\s+(\w+)", bad_acceptance)).issubset(
            {"state", "popup", "closePopup", "popupState"}):
        errors.append("Bluetooth acceptance matcher missed a mutation fixture")


def main() -> int:
    errors: list[str] = []
    for relative in REQUIRED_FILES:
        if not (ROOT / relative).is_file():
            errors.append(f"missing Bluetooth file: {relative}")
    validate_native_importer(errors)
    validate_service(errors)
    validate_presentation(errors)
    validate_presentation_gate_fixtures(errors)
    validate_integration(errors)
    validate_integration_gate_fixtures(errors)
    validate_gate_fixtures(errors)
    validate_rules_contract(errors)

    qmldir = BLUETOOTH_ROOT / "qmldir"
    if qmldir.is_file():
        source = qmldir.read_text(encoding="utf-8")
        if "module qs.Titonium.Services.Bluetooth" not in source:
            errors.append("Bluetooth qmldir module name is missing")
        if "singleton BluetoothService 1.0 BluetoothService.qml" not in source:
            errors.append("Bluetooth qmldir must export BluetoothService singleton")

    if errors:
        for error in errors:
            print(f"FAIL {error}")
        return 1

    print("PASS Bluetooth service architecture")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
