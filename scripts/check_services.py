#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = (
    "Titonium/Services/Applications/ApplicationService.qml",
    "Titonium/Services/Applications/ApplicationLaunch.js",
    "Titonium/Services/Applications/Visibility.js",
    "Titonium/Services/Applications/qmldir",
    "Titonium/Services/Clipboard/ClipboardService.qml",
    "Titonium/Services/Clipboard/ClipboardAccess.js",
    "Titonium/Services/Clipboard/ClipboardHistory.js",
    "Titonium/Services/Clipboard/qmldir",
    "Titonium/Services/Hyprland/HyprlandService.qml",
    "Titonium/Services/Hyprland/qmldir",
    "Titonium/Services/InputMethod/InputMethodService.qml",
    "Titonium/Services/InputMethod/qmldir",
    "Titonium/Services/Audio/AudioService.qml",
    "Titonium/Services/Audio/AudioRules.js",
    "Titonium/Services/Audio/qmldir",
)


def main() -> int:
    errors: list[str] = []
    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            errors.append(f"missing service file: {relative}")

    for relative in (
        "Titonium/Services/Applications/ApplicationService.qml",
        "Titonium/Services/Hyprland/HyprlandService.qml",
        "Titonium/Services/InputMethod/InputMethodService.qml",
        "Titonium/Services/Audio/AudioService.qml",
    ):
        path = ROOT / relative
        if not path.is_file():
            continue
        source = path.read_text(encoding="utf-8")
        if re.search(r"\b(Process|Timer)\s*\{|Quickshell\.execDetached", source):
            errors.append(f"event-driven service owns polling/process: {relative}")

    overlay = ROOT / "Titonium/Core/Surfaces/OverlayHost.qml"
    if overlay.is_file() and "qs.Titonium.Platform.Hyprland" in overlay.read_text(encoding="utf-8"):
        errors.append("Core OverlayHost still imports the superseded Hyprland adapter")

    if errors:
        print("FAIL service contract")
        print("\n".join(errors))
        return 1
    print("PASS service contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
