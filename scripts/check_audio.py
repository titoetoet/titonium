#!/usr/bin/env python3

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO_ROOT = ROOT / "Titonium/Services/Audio"
OVERLAY_ROOT = ROOT / "Titonium/Overlays/Audio"
OSD_ROOT = ROOT / "Titonium/Osd/Audio"
REQUIRED_FILES = (
    "Titonium/Services/Audio/AudioService.qml",
    "Titonium/Services/Audio/AudioRules.js",
    "Titonium/Services/Audio/qmldir",
)
REQUIRED_OVERLAY_FILES = (
    "Titonium/Overlays/Audio/qmldir",
    "Titonium/Overlays/Audio/AudioPopupCoordinator.qml",
    "Titonium/Overlays/Audio/AudioPopupSurface.qml",
    "Titonium/Overlays/Audio/AudioControlRow.qml",
    "Titonium/Overlays/Audio/AudioStreamRow.qml",
    "Titonium/Overlays/Audio/AudioSlider.qml",
)
REQUIRED_OSD_FILES = (
    "Titonium/Osd/Audio/qmldir",
    "Titonium/Osd/Audio/AudioOsdCoordinator.qml",
    "Titonium/Osd/Audio/AudioOsdHost.qml",
    "Titonium/Osd/Audio/AudioOsd.qml",
)
REQUIRED_FRAGMENTS = (
    "import Quickshell.Services.Pipewire",
    "PwObjectTracker {",
    "objects: Pipewire.nodes.values.filter",
    "readonly property bool outputAvailable",
    "readonly property bool allowAmplification: Preferences.allowAudioAmplification",
    "readonly property var playbackStreams",
    "signal outputPresentationChanged(real volume, bool muted)",
    "function setOutputVolume(value: real): bool",
    "function adjustOutputVolume(delta: real): bool",
    "function toggleOutputMute(): bool",
    "function setInputVolume(value: real): bool",
    "function toggleInputMute(): bool",
    "function setStreamVolume(nodeId: int, value: real): bool",
    "function toggleStreamMute(nodeId: int): bool",
    "function onVolumesChanged(): void { root.observeOutputPresentation(); }",
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
WRONG_OUTPUT_PRESENTATION_NOTIFIER = (
    "function onVolumeChanged(): void { root.observeOutputPresentation(); }"
)


def require_fragments(errors: list[str], path: Path, fragments: tuple[str, ...], label: str) -> None:
    if not path.is_file():
        return
    source = path.read_text(encoding="utf-8")
    for fragment in fragments:
        if fragment not in source:
            errors.append(f"{label} missing contract: {fragment}")


def main() -> int:
    errors: list[str] = []
    for relative in REQUIRED_FILES:
        if not (ROOT / relative).is_file():
            errors.append(f"missing audio file: {relative}")
    for relative in REQUIRED_OVERLAY_FILES:
        if not (ROOT / relative).is_file():
            errors.append(f"missing audio overlay file: {relative}")
    for relative in REQUIRED_OSD_FILES:
        if not (ROOT / relative).is_file():
            errors.append(f"missing audio OSD file: {relative}")

    service = AUDIO_ROOT / "AudioService.qml"
    if service.is_file():
        source = service.read_text(encoding="utf-8")
        for fragment in REQUIRED_FRAGMENTS:
            if fragment not in source:
                errors.append(f"missing audio service contract: {fragment}")
        for fragment in FORBIDDEN_SERVICE_FRAGMENTS:
            if fragment in source:
                errors.append(f"forbidden audio service dependency: {fragment}")
        if WRONG_OUTPUT_PRESENTATION_NOTIFIER in source:
            errors.append("output presentation must observe PwNodeAudio.volumesChanged, not volumeChanged")
        if "Preferences.settings.modules?.audio?.allowAmplification" in source:
            errors.append("audio service must use Preferences.allowAudioAmplification")

    for path in ROOT.rglob("*.qml"):
        if AUDIO_ROOT in path.parents:
            continue
        if "import Quickshell.Services.Pipewire" in path.read_text(encoding="utf-8"):
            errors.append(f"PipeWire import outside audio service: {path.relative_to(ROOT)}")

    require_fragments(errors, OVERLAY_ROOT / "qmldir", (
        "module qs.Titonium.Overlays.Audio",
        "singleton AudioPopupCoordinator 1.0 AudioPopupCoordinator.qml",
    ), "Audio overlay module")
    require_fragments(errors, OVERLAY_ROOT / "AudioPopupCoordinator.qml", (
        "pragma Singleton",
        "function open(screen: var): bool",
        "function toggle(screen: var): bool",
        "function close(): bool",
        '"source": Qt.resolvedUrl("AudioPopupSurface.qml")',
        '"keyboardFocus": "exclusive"',
        '"closeOnMonitorChange": true',
        '"ownerId": owner',
        "SurfaceManager.ownerId === root.ownerFor(screen)",
    ), "Audio popup coordinator")
    require_fragments(errors, OVERLAY_ROOT / "AudioPopupSurface.qml", (
        "TapHandler {",
        "Keys.onEscapePressed",
        "width: 380",
        "anchors.topMargin: 40 + Metrics.barSpacing",
        "anchors.rightMargin: Metrics.barPadding",
        "maximumHeight: 520",
        "ListView {",
        "AudioControlRow {",
        "AudioStreamRow {",
    ), "Audio popup surface")
    require_fragments(errors, OVERLAY_ROOT / "AudioSlider.qml", (
        "property real serviceValue: 0",
        "property real maximumValue: 1",
        "signal userValueChanged(real value)",
        "QtControls.Slider",
        "onMoved:",
    ), "Audio slider")
    require_fragments(errors, OVERLAY_ROOT / "AudioControlRow.qml", (
        'property string kind: "output"',
        "AudioService.setOutputVolume",
        "AudioService.toggleOutputMute",
        "AudioService.setInputVolume",
        "AudioService.toggleInputMute",
        'I18n.tr(root.muted ? "audio.unmute.accessible" : "audio.mute.accessible", {',
        '"name": root.label',
    ), "Audio control row")
    require_fragments(errors, OVERLAY_ROOT / "AudioStreamRow.qml", (
        "required property var stream",
        "AudioService.setStreamVolume",
        "AudioService.toggleStreamMute",
        'I18n.tr(root.muted ? "audio.unmute.accessible" : "audio.mute.accessible", {',
        '"name": root.stream?.name || I18n.tr("audio.stream.fallback")',
    ), "Audio stream row")

    require_fragments(errors, OSD_ROOT / "qmldir", (
        "module qs.Titonium.Osd.Audio",
        "singleton AudioOsdCoordinator 1.0 AudioOsdCoordinator.qml",
    ), "Audio OSD module")
    require_fragments(errors, OSD_ROOT / "AudioOsdCoordinator.qml", (
        "pragma Singleton",
        "readonly property bool active",
        "readonly property bool presented",
        "readonly property string ownerScreenName",
        "function onOutputPresentationChanged(volume: real, muted: bool): void",
        "HyprlandService.focusedMonitorName",
        "function show(screenName: string, volume: real, muted: bool): bool",
        "function hide(): bool",
        "interval: 1200",
        "repeat: false",
        "hideTimer.restart()",
        "exitTimer.stop()",
        "exitTimer.restart()",
        "interval: Motion.fast",
    ), "Audio OSD coordinator")
    require_fragments(errors, OSD_ROOT / "AudioOsdHost.qml", (
        "Variants {",
        "model: Quickshell.screens",
    ), "Audio OSD host")
    require_fragments(errors, OSD_ROOT / "AudioOsd.qml", (
        'I18n.tr("audio.muted")',
        'I18n.tr("audio.osd.volume", {',
        "Behavior on opacity",
        "Behavior on y",
        "Motion.fast",
        "property bool requestedPresented: false",
        "property bool presented: false",
        "opacity: root.presented ? 1 : 0",
        "y: root.presented ? 0 : 8",
    ), "Audio OSD pill")

    osd_host = OSD_ROOT / "AudioOsdHost.qml"
    if osd_host.is_file():
        source = osd_host.read_text(encoding="utf-8")
        for fragment in (
            "PanelWindow {",
            "Loader {",
            "active: window.visible",
            "requestedPresented: AudioOsdCoordinator.presented",
            "WlrKeyboardFocus.None",
            "exclusiveZone: 0",
            "anchors { bottom: true; left: false; right: false }",
            "mask: Region {}",
        ):
            if fragment not in source:
                errors.append(f"Audio OSD host missing contract: {fragment}")

    osd_pill = OSD_ROOT / "AudioOsd.qml"
    if osd_pill.is_file() and "property bool entered" in osd_pill.read_text(encoding="utf-8"):
        errors.append("Audio OSD must use coordinator presented state, not entry-only state")

    if OSD_ROOT.exists():
        osd_source = "\n".join(path.read_text(encoding="utf-8") for path in OSD_ROOT.rglob("*.qml"))
        for forbidden in (
            "Quickshell.Services.Pipewire",
            "SurfaceManager",
            "Process",
            "FileView",
            "TapHandler",
            "MouseArea",
            "PointerHandler",
            "WheelHandler",
            ".audio.volume =",
            ".audio.muted =",
        ):
            if forbidden in osd_source:
                errors.append(f"Audio OSD contains forbidden dependency: {forbidden}")
        if "repeat: true" in osd_source:
            errors.append("Audio OSD timer must not repeat")
        service_imports = re.findall(
            r"^\s*import\s+(qs\.Titonium\.Services\.[A-Za-z.]+)", osd_source, re.MULTILINE
        )
        if any(import_name not in ("qs.Titonium.Services.Audio", "qs.Titonium.Services.Hyprland")
               for import_name in service_imports):
            errors.append("Audio OSD imports an unsupported service")

    for locale in ("en", "vi"):
        catalog_path = ROOT / f"config/i18n/{locale}.json"
        if not catalog_path.is_file():
            continue
        strings = json.loads(catalog_path.read_text(encoding="utf-8")).get("strings", {})
        for key in ("audio.mute.accessible", "audio.unmute.accessible", "audio.osd.volume"):
            if key not in strings:
                errors.append(f"{locale} catalog missing audio accessibility key: {key}")

    if OVERLAY_ROOT.exists():
        overlay_source = "\n".join(path.read_text(encoding="utf-8") for path in OVERLAY_ROOT.rglob("*.qml"))
        for forbidden in (
            "Quickshell.Services.Pipewire",
            ".audio.volume =",
            ".audio.muted =",
            "Process",
            "FileView",
            "execDetached",
            "wpctl",
            "pactl",
            "Timer {",
        ):
            if forbidden in overlay_source:
                errors.append(f"Audio overlay contains forbidden dependency: {forbidden}")
        service_imports = re.findall(
            r"^\s*import\s+(qs\.Titonium\.Services\.[A-Za-z.]+)", overlay_source, re.MULTILINE
        )
        if any(import_name != "qs.Titonium.Services.Audio" for import_name in service_imports):
            errors.append("Audio overlay imports a service other than AudioService")

    require_fragments(errors, ROOT / "Titonium/Bar/islands/ConnectivityPill.qml", (
        "required property var screen",
        "AudioPopupCoordinator.toggle(root.screen)",
        "AudioService.adjustOutputVolume",
        "WheelHandler {",
    ), "Connectivity pill")
    require_fragments(errors, ROOT / "Titonium/App.qml", (
        "import qs.Titonium.Overlays.Audio",
        "function popup(): string",
        "function closePopup(): string",
        "function popupState(): string",
        "import qs.Titonium.Osd.Audio",
        "AudioOsdHost {}",
        "function osdState(): string",
        "AudioOsdCoordinator.active",
        "AudioOsdCoordinator.ownerScreenName",
        "AudioPopupCoordinator.open(screen)",
        "AudioPopupCoordinator.close()",
        "function onOpened(ownerId: string, descriptor: var, screen: var): void",
        "CenterNotchCoordinator.close()",
    ), "App audio popup IPC")

    if errors:
        print("FAIL audio contract")
        print("\n".join(errors))
        return 1
    print("PASS audio contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
