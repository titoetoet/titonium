#!/usr/bin/env python3

import re
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
ROOT_NATIVE_MEMBER = re.compile(
    r"^    (?:readonly\s+)?property\s+var\s+native(?:Adapter|Devices|DeviceInputs)\s*:"
    r"|^    function\s+nativeDeviceForAddress\s*\(", re.MULTILINE)


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

    if ROOT_NATIVE_MEMBER.search(source):
        errors.append("Bluetooth native objects and lookups must not be public singleton members")

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
