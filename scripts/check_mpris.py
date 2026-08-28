#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TITONIUM = ROOT / "Titonium"
MPRIS = TITONIUM / "Services/Mpris"
SERVICE = MPRIS / "MprisService.qml"
QMLDIR = MPRIS / "qmldir"
APP = TITONIUM / "App.qml"


def main() -> int:
    errors: list[str] = []

    native_import_owners: list[Path] = []
    for path in TITONIUM.rglob("*.qml"):
        source = path.read_text(encoding="utf-8")
        if re.search(r"^\s*import\s+Quickshell\.Services\.Mpris\s*$", source, re.MULTILINE):
            native_import_owners.append(path)
    expected_owner = SERVICE.resolve()
    if len(native_import_owners) != 1 or native_import_owners[0].resolve() != expected_owner:
        owners = ", ".join(str(path.relative_to(ROOT)) for path in native_import_owners) or "none"
        errors.append(f"MPRIS native import must have exactly one service owner; found: {owners}")

    for path in (SERVICE, QMLDIR):
        if not path.is_file():
            errors.append(f"missing MPRIS service contract: {path.relative_to(ROOT)}")

    if SERVICE.is_file():
        source = SERVICE.read_text(encoding="utf-8")
        for fragment in (
            "pragma Singleton",
            "readonly property var playerFacts:",
            "readonly property var selectedPlayer:",
            "readonly property bool playing:",
            "readonly property string title:",
            "Mpris.players.values",
            "MprisPlaybackState.toString",
            "Instantiator {",
            "model: Mpris.players",
            "target: Mpris.players",
            "function onValuesChanged():",
            "function onTrackTitleChanged():",
            "function onTrackArtistChanged():",
            "function onPlaybackStateChanged():",
            "MprisRules.transition",
            "CenterAttentionService.publish",
            "CenterAttentionService.setIndicator",
            '"menubar.center.indicator.media"',
            '"menubar.center.media_unknown"',
            "function snapshot(): string",
        ):
            if fragment not in source:
                errors.append(f"MprisService missing contract: {fragment}")
        for forbidden in (
            "Process {",
            "Timer {",
            "FileView {",
            "Quickshell.execDetached",
            "import qs.Titonium.Bar",
            "import qs.Titonium.Overlays",
            "priority:",
            "ttl:",
            "artUrl",
            "position:",
        ):
            if forbidden in source:
                errors.append(f"MprisService has forbidden ownership: {forbidden}")
        if re.search(r"readonly\s+property\s+var\s+(?:native|playerObject|rawPlayer)", source):
            errors.append("MprisService must not expose a native player object")

    if QMLDIR.is_file():
        source = QMLDIR.read_text(encoding="utf-8")
        for fragment in (
            "module qs.Titonium.Services.Mpris",
            "singleton MprisService 1.0 MprisService.qml",
        ):
            if fragment not in source:
                errors.append(f"MPRIS qmldir missing contract: {fragment}")

    app = APP.read_text(encoding="utf-8")
    if app.count("import qs.Titonium.Services.Mpris") != 1:
        errors.append("App must import the MPRIS service module exactly once")

    for path in (TITONIUM / "Bar").rglob("*.qml"):
        source = path.read_text(encoding="utf-8")
        if "Quickshell.Services.Mpris" in source or "Mpris.players" in source:
            errors.append(f"Bar view owns native MPRIS state: {path.relative_to(ROOT)}")

    if errors:
        print("FAIL MPRIS service architecture")
        print("\n".join(errors))
        return 1
    print("PASS sole native MPRIS ownership and Center adapter boundary")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
