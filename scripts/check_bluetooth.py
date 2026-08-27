#!/usr/bin/env python3

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
}
PUBLIC_FUNCTIONS = {
    "warnOperation", "setPowered", "setDiscovering", "connectDevice", "disconnectDevice",
    "pairDevice", "cancelPair", "forgetDevice", "snapshot",
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


def main() -> int:
    errors: list[str] = []
    for relative in REQUIRED_FILES:
        if not (ROOT / relative).is_file():
            errors.append(f"missing Bluetooth file: {relative}")
    validate_native_importer(errors)
    validate_service(errors)
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
