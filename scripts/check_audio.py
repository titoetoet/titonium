#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO_ROOT = ROOT / "Titonium/Services/Audio"
REQUIRED_FILES = (
    "Titonium/Services/Audio/AudioService.qml",
    "Titonium/Services/Audio/AudioRules.js",
    "Titonium/Services/Audio/qmldir",
)
REQUIRED_FRAGMENTS = (
    "import Quickshell.Services.Pipewire",
    "PwObjectTracker {",
    "objects: Pipewire.nodes.values.filter",
    "readonly property bool outputAvailable",
    "readonly property var playbackStreams",
    "signal outputPresentationChanged(real volume, bool muted)",
    "function setOutputVolume(value: real): bool",
    "function adjustOutputVolume(delta: real): bool",
    "function toggleOutputMute(): bool",
    "function setInputVolume(value: real): bool",
    "function toggleInputMute(): bool",
    "function setStreamVolume(nodeId: int, value: real): bool",
    "function toggleStreamMute(nodeId: int): bool",
)
FORBIDDEN_SERVICE_FRAGMENTS = (
    "Process",
    "FileView",
    "execDetached",
    "wpctl",
    "pactl",
    "Timer {",
    "qs.Titonium.Services.Mpris",
    "qs.Titonium.Services.Bluetooth",
    "qs.Titonium.Services.Network",
)


def main() -> int:
    errors: list[str] = []
    for relative in REQUIRED_FILES:
        if not (ROOT / relative).is_file():
            errors.append(f"missing audio file: {relative}")

    service = AUDIO_ROOT / "AudioService.qml"
    if service.is_file():
        source = service.read_text(encoding="utf-8")
        for fragment in REQUIRED_FRAGMENTS:
            if fragment not in source:
                errors.append(f"missing audio service contract: {fragment}")
        for fragment in FORBIDDEN_SERVICE_FRAGMENTS:
            if fragment in source:
                errors.append(f"forbidden audio service dependency: {fragment}")

    for path in ROOT.rglob("*.qml"):
        if AUDIO_ROOT in path.parents:
            continue
        if "import Quickshell.Services.Pipewire" in path.read_text(encoding="utf-8"):
            errors.append(f"PipeWire import outside audio service: {path.relative_to(ROOT)}")

    if errors:
        print("FAIL audio contract")
        print("\n".join(errors))
        return 1
    print("PASS audio contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
