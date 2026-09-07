#!/usr/bin/env python3
"""Static contract for design-style paint adoption in shell consumers."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


REQUIRED = {
    "Titonium/Dock/DockSurface.qml": (("Shared.StylePaint", 2), ("role: \"button\"", 2)),
    "Titonium/Dock/DockAppButton.qml": (("Shared.StylePaint", 1), ("customColor: root.dockItem?.active", 1)),
    "Titonium/Overlays/Audio/AudioOutputDeviceRow.qml": (("Shared.StylePaint", 1), ("role: \"menu-row\"", 1)),
    "Titonium/Overlays/Audio/AudioSlider.qml": (("Shared.StylePaint", 2), ("role: \"field\"", 1)),
    "Titonium/Overlays/Bluetooth/BluetoothDeviceRow.qml": (("Shared.StylePaint", 1), ("role: \"menu-row\"", 1)),
    "Titonium/Overlays/Network/WifiNetworkRow.qml": (("Shared.StylePaint", 1), ("role: \"field\"", 1)),
    "Titonium/Overlays/SystemTray/SystemTrayMenuView.qml": (("Shared.StylePaint", 1), ("selected: menuRow.inputPresentation.selected", 1)),
    "Titonium/Overlays/Spotlight/SearchResults.qml": (("Controls.StylePaint", 1), ("role: \"menu-row\"", 1)),
    "Titonium/Overlays/Spotlight/SpotlightSurface.qml": (("Controls.StylePaint", 1), ("role: \"field\"", 1)),
    "Titonium/Overlays/Spotlight/ApplicationTile.qml": (("Controls.StylePaint", 1), ("selected: root.selected", 1)),
    "Titonium/Overlays/WindowSwitcher/WindowSwitcherTile.qml": (("Shared.StylePaint", 1), ("customColor: root.tileColor", 1)),
    "Titonium/Bar/center/MusicSeek.qml": (("Shared.StylePaint", 2), ("role: \"field\"", 1)),
    "Titonium/Bar/center/CenterCompactCapsule.qml": (("Shared.StylePaint", 3), ("role: \"menu-row\"", 1)),
}

# Raw rectangles that remain intentionally primitive content or geometry sentinels.
RAW_RECTANGLE_EXCEPTIONS = {
    "Titonium/Dock/DockAppButton.qml": 2,  # legacy chrome + running/urgent indicator
    "Titonium/Dock/DockItemMenuSurface.qml": 1,  # transparent outside-click catcher
    "Titonium/Overlays/SystemTray/SystemTrayMenuView.qml": 2,  # legacy row + separator
    "Titonium/Notifications/NotificationHistoryContent.qml": 1,  # separator
}


def main() -> None:
    failures = []
    for relative, requirements in REQUIRED.items():
        source = (ROOT / relative).read_text()
        for fragment, minimum in requirements:
            count = source.count(fragment)
            if count < minimum:
                failures.append(f"{relative}: expected {minimum}x {fragment!r}, found {count}")
        if "Theme.legacy" not in source:
            failures.append(f"{relative}: legacy paint branch is missing")

    for relative, maximum in RAW_RECTANGLE_EXCEPTIONS.items():
        source = (ROOT / relative).read_text()
        count = len(re.findall(r"\bRectangle\s*\{", source))
        if count > maximum:
            failures.append(
                f"{relative}: {count} raw Rectangles exceed {maximum} intentional exception(s)"
            )

    if failures:
        raise SystemExit("style consumer contract failed:\n- " + "\n- ".join(failures))
    print("style consumer contract passed")


if __name__ == "__main__":
    main()
