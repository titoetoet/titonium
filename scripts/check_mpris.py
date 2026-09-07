#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TITONIUM = ROOT / "Titonium"
MPRIS = TITONIUM / "Services/Mpris"
SERVICE = MPRIS / "MprisService.qml"
QMLDIR = MPRIS / "qmldir"
APP = TITONIUM / "App.qml"
ACCEPTANCE = ROOT / "scripts/mpris_acceptance.sh"


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
            "function selectedNativePlayer(): var",
            "function togglePlaying(): bool",
            "function previous(): bool",
            "function next(): bool",
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
            "MprisRules.indicatorActive(result.next)",
            "CenterAttentionService.publish",
            "CenterAttentionService.setIndicator",
            '"menubar.center.indicator.media"',
            '"menubar.center.media_unknown"',
            "function snapshot(): string",
            "function activate(): void",
        ):
            if fragment not in source:
                errors.append(f"MprisService missing contract: {fragment}")
        for forbidden in (
            "FileView {",
            "Quickshell.execDetached",
            "import qs.Titonium.Bar",
            "import qs.Titonium.Overlays",
            "priority:",
            "ttl:",
        ):
            if forbidden in source:
                errors.append(f"MprisService has forbidden ownership: {forbidden}")
        # Approved Music details add one read-only TrackList signal adapter and a
        # visible-only clock reading Quickshell's interpolated position (no DBus poll).
        if source.count("Process {") != 1 or source.count("Timer {") != 1:
            errors.append("MPRIS details must retain one queue reader and one position clock")
        if "running: root.detailsActive && root.playing" not in source:
            errors.append("MPRIS position clock must stop outside visible playing details")
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

    app = (TITONIUM / "Orchestration/ServiceBootstrap.qml").read_text(encoding="utf-8")
    app += (TITONIUM / "Ipc/CenterIpc.qml").read_text(encoding="utf-8")
    if app.count("import qs.Titonium.Services.Mpris") != 2:
        errors.append("Bootstrap and CenterIpc must each import the MPRIS service module")
    for fragment in (
        "MprisService.activate()",
        'target: "mpris"',
        "function state(): string { return MprisService.snapshot(); }",
    ):
        if fragment not in app:
            errors.append(f"App missing read-only MPRIS IPC contract: {fragment}")
    mpris_ipc = re.search(
        r'IpcHandler\s*\{\s*target:\s*"mpris"(?P<body>.*?)(?=\n\s*(?:property\s+IpcHandler\s+\w+\s*:\s*)?IpcHandler\s*\{|\Z)',
        app,
        re.DOTALL,
    )
    if mpris_ipc:
        body = mpris_ipc.group("body")
        for forbidden in ("play(", "pause(", "seek(", "next(", "previous(", "publish("):
            if forbidden in body:
                errors.append(f"MPRIS IPC exposes mutation: {forbidden}")

    for path in (TITONIUM / "Bar").rglob("*.qml"):
        source = path.read_text(encoding="utf-8")
        if "Quickshell.Services.Mpris" in source or "Mpris.players" in source:
            errors.append(f"Bar view owns native MPRIS state: {path.relative_to(ROOT)}")

    if not ACCEPTANCE.is_file():
        errors.append("missing scripts/mpris_acceptance.sh")
    else:
        acceptance = ACCEPTANCE.read_text(encoding="utf-8")
        for fragment in (
            "qs -n -p",
            "mpris state",
            "center state",
            "hyprctl -j layers",
            "titonium-menubar",
            "DP-1",
            "DP-3",
            "Configuration Loaded",
            "before_git",
            "before_live",
            "before_dotfiles",
        ):
            if fragment not in acceptance:
                errors.append(f"MPRIS acceptance missing read-only contract: {fragment}")
        for forbidden in (
            "playerctl",
            "dbus-send",
            "mpris play",
            "mpris pause",
            "mpris seek",
            "mpris next",
            "mpris previous",
            "center publish",
        ):
            if forbidden in acceptance:
                errors.append(f"MPRIS acceptance contains mutation: {forbidden}")

    if errors:
        print("FAIL MPRIS service architecture")
        print("\n".join(errors))
        return 1
    print("PASS sole native MPRIS ownership and Center adapter boundary")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
