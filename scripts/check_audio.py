#!/usr/bin/env python3

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO_ROOT = ROOT / "Titonium/Services/Audio"
OVERLAY_ROOT = ROOT / "Titonium/Overlays/Audio"
OSD_ROOT = ROOT / "Titonium/Osd/Audio"
AUDIO_SOURCE_ROOTS = (
    AUDIO_ROOT,
    OVERLAY_ROOT,
    OSD_ROOT,
    ROOT / "Titonium/Bar/islands/ConnectivityPill.qml",
    ROOT / "Titonium/App.qml",
)
REQUIRED_FILES = (
    "Titonium/Services/Audio/AudioService.qml",
    "Titonium/Services/Audio/AudioRules.js",
    "Titonium/Services/Audio/qmldir",
)
REQUIRED_OVERLAY_FILES = (
    "Titonium/Overlays/Audio/qmldir",
    "Titonium/Overlays/Audio/AudioPopupCoordinator.qml",
    "Titonium/Overlays/Audio/AudioPopupSurface.qml",
    "Titonium/Overlays/Audio/ClassicAudioPopupSurface.qml",
    "Titonium/Overlays/Audio/AudioControlRow.qml",
    "Titonium/Overlays/Audio/AudioOutputDeviceRow.qml",
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
    "readonly property var outputDevices",
    "readonly property var audioNodeFacts:",
    "audio: node?.audio ? ({",
    "AudioRules.normalizedStreams(root.audioNodeFacts",
    "signal outputPresentationChanged(real volume, bool muted)",
    "function setOutputVolume(value: real): bool",
    "function adjustOutputVolume(delta: real): bool",
    "function toggleOutputMute(): bool",
    "function setInputVolume(value: real): bool",
    "function toggleInputMute(): bool",
    "function selectOutputDevice(nodeId: int): bool",
    "function setStreamVolume(nodeId: int, value: real): bool",
    "function toggleStreamMute(nodeId: int): bool",
    "function onVolumesChanged(): void { root.observeOutputPresentation(); }",
    "function onOutputAvailableChanged(): void { root.resetOutputPresentation(); }",
    "readonly property int invalidVolumeWarningLimit: 3",
    "function warnInvalidVolume(target: string): void",
    "function requestBluetoothOutput(address: string): bool",
    "function trySelectPendingBluetoothOutput(): bool",
    "signal bluetoothOutputSelected(string address)",
    "AudioRules.bluetoothSinkFor(Pipewire.nodes.values || [],",
    "AudioRules.normalizedOutputDevices(root.audioNodeFacts",
    "Pipewire.preferredDefaultAudioSink = sink",
    "function onObjectsChanged(): void { root.trySelectPendingBluetoothOutput(); }",
    'root.warnInvalidVolume("output")',
    'root.warnInvalidVolume("input")',
    'root.warnInvalidVolume("stream")',
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
FORBIDDEN_AUDIO_DEPENDENCIES = (
    "Process",
    "FileView",
    "execDetached",
    "wpctl",
    "pactl",
)
FORBIDDEN_AUDIO_SERVICE_IMPORTS = re.compile(
    r"^\s*import\s+.*(?:Mpris|Bluetooth|Network|Notifications)", re.MULTILINE | re.IGNORECASE
)
RAW_AUDIO_MUTATION = re.compile(r"\.audio\.(?:volume|muted)\s*=")
MUTATING_AUDIO_IPC_METHOD = re.compile(
    r"^\s*function\s+(?:(?:set|adjust|showOsd|device)\w*|toggle\w*Mute)\s*\(", re.MULTILINE
)
FORBIDDEN_AUDIO_IPC_BODY_CALL = re.compile(r"\bAudioOsdCoordinator\s*\.\s*show\s*\(")
MUTATING_AUDIO_IPC_FIXTURES = (
    "function toggleOutputMute(): string { return \"mutated\"; }",
    "function toggleInputMute(): string { return \"mutated\"; }",
    "function preview(): string { AudioOsdCoordinator.show(\"DP-1\", 0.5, false); return \"shown\"; }",
)


def require_fragments(errors: list[str], path: Path, fragments: tuple[str, ...], label: str) -> None:
    if not path.is_file():
        return
    source = path.read_text(encoding="utf-8")
    for fragment in fragments:
        if fragment not in source:
            errors.append(f"{label} missing contract: {fragment}")


def qml_files(paths: tuple[Path, ...]) -> tuple[Path, ...]:
    files: set[Path] = set()
    for path in paths:
        if path.is_dir():
            files.update(path.rglob("*.qml"))
        elif path.is_file():
            files.add(path)
    return tuple(sorted(files))


def audio_source_files(paths: tuple[Path, ...]) -> tuple[Path, ...]:
    files: set[Path] = set()
    for path in paths:
        if path.is_dir():
            files.update(path.rglob("*.qml"))
            files.update(path.rglob("*.js"))
        elif path.is_file():
            files.add(path)
    return tuple(sorted(files))


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


def ipc_handler_source(source: str, target: str) -> str:
    for match in re.finditer(r"\bIpcHandler\s*\{", source):
        block = qml_block(source, match.start())
        if re.search(rf'\btarget\s*:\s*"{re.escape(target)}"', block):
            return block
    return ""


def audio_ipc_exposes_mutation(source: str) -> bool:
    return bool(MUTATING_AUDIO_IPC_METHOD.search(source)
                or FORBIDDEN_AUDIO_IPC_BODY_CALL.search(source))


def forbidden_audio_service_imports(path: Path, source: str) -> list[str]:
    """Allow sibling services only at their explicit shared composition boundary."""
    imports = FORBIDDEN_AUDIO_SERVICE_IMPORTS.findall(source)
    if path == ROOT / "Titonium/Bar/islands/ConnectivityPill.qml":
        return [entry for entry in imports
                if "Bluetooth" not in entry and "Network" not in entry
                and "Notifications" not in entry]
    if path == ROOT / "Titonium/App.qml":
        return [entry for entry in imports
                if "Bluetooth" not in entry and "Network" not in entry
                and "Notifications" not in entry and "Mpris" not in entry]
    return imports


def validate_audio_hardening(errors: list[str]) -> None:
    for fixture in MUTATING_AUDIO_IPC_FIXTURES:
        if not audio_ipc_exposes_mutation(fixture):
            errors.append(f"Audio IPC mutation matcher missed fixture: {fixture.split('(')[0]}")

    audio_files = audio_source_files(AUDIO_SOURCE_ROOTS)
    for path in audio_files:
        source = path.read_text(encoding="utf-8")
        relative = path.relative_to(ROOT)
        if re.search(r"\bTimer\s*\{", source) and re.search(r"\brepeat\s*:\s*true\b", source):
            errors.append(f"Audio timer repeats: {relative}")
        for dependency in FORBIDDEN_AUDIO_DEPENDENCIES:
            if dependency in source:
                errors.append(f"forbidden Audio dependency {dependency}: {relative}")
        if forbidden_audio_service_imports(path, source):
            errors.append(f"forbidden Audio service import: {relative}")

    shared_pill = ROOT / "Titonium/Bar/islands/ConnectivityPill.qml"
    shared_source = shared_pill.read_text(encoding="utf-8") if shared_pill.is_file() else ""
    if "import qs.Titonium.Services.Bluetooth" not in shared_source:
        errors.append("ConnectivityPill must retain its shared Bluetooth service import")
    if "import qs.Titonium.Services.Network" not in shared_source:
        errors.append("ConnectivityPill must own its shared Network service import")

    bad_overlay = OVERLAY_ROOT / "BadBluetoothImport.qml"
    if not forbidden_audio_service_imports(
            bad_overlay, "import qs.Titonium.Services.Bluetooth\nQtObject {}"):
        errors.append("Audio import matcher missed Bluetooth overlay fixture")
    if forbidden_audio_service_imports(
            shared_pill, "import qs.Titonium.Services.Bluetooth\nItem {}"):
        errors.append("Audio import matcher rejected the allowed shared ConnectivityPill fixture")
    if forbidden_audio_service_imports(
            shared_pill, "import qs.Titonium.Services.Network\nItem {}"):
        errors.append("Audio import matcher rejected the allowed shared Network pill fixture")
    if forbidden_audio_service_imports(
            shared_pill, "import qs.Titonium.Services.Notifications\nItem {}"):
        errors.append("Audio import matcher rejected Notifications at the shared pill")
    if forbidden_audio_service_imports(
            ROOT / "Titonium/App.qml", "import qs.Titonium.Services.Network\nScope {}"):
        errors.append("Audio import matcher rejected Network at the App composition root")
    if forbidden_audio_service_imports(
            ROOT / "Titonium/App.qml", "import qs.Titonium.Services.Notifications\nScope {}"):
        errors.append("Audio import matcher rejected Notifications at App composition")
    if not forbidden_audio_service_imports(
            OVERLAY_ROOT / "BadNotificationImport.qml",
            "import qs.Titonium.Services.Notifications\nItem {}"):
        errors.append("Audio import matcher missed Notifications overlay fixture")
    if forbidden_audio_service_imports(
            ROOT / "Titonium/App.qml", "import qs.Titonium.Services.Mpris\nScope {}"):
        errors.append("Audio import matcher rejected MPRIS at the App composition root")
    if not forbidden_audio_service_imports(
            OVERLAY_ROOT / "BadMprisImport.qml",
            "import qs.Titonium.Services.Mpris\nItem {}"):
        errors.append("Audio import matcher missed MPRIS overlay fixture")

    for pattern in ("*.qml", "*.js"):
        for path in ROOT.rglob(pattern):
            if AUDIO_ROOT in path.parents:
                continue
            if RAW_AUDIO_MUTATION.search(path.read_text(encoding="utf-8")):
                errors.append(f"raw audio mutation outside Services/Audio: {path.relative_to(ROOT)}")

    overlay_loaders = [
        path.relative_to(ROOT)
        for path in qml_files((OVERLAY_ROOT,))
        if re.search(r"\bLoader\s*\{", path.read_text(encoding="utf-8"))
    ]
    if overlay_loaders:
        errors.append("Audio popup Loader bypasses OverlayHost lifecycle: "
                      + ", ".join(str(path) for path in overlay_loaders))

    osd_host = OSD_ROOT / "AudioOsdHost.qml"
    osd_loader_paths = [
        path for path in qml_files((OSD_ROOT,))
        if re.search(r"\bLoader\s*\{", path.read_text(encoding="utf-8"))
    ]
    if osd_loader_paths != [osd_host]:
        errors.append("Audio OSD Loader must exist only in AudioOsdHost")
    elif osd_host.is_file():
        source = osd_host.read_text(encoding="utf-8")
        loader_count = len(re.findall(r"\bLoader\s*\{", source))
        osd_lifecycle = (
            "readonly property bool ownsOsd: AudioOsdCoordinator.active",
            "AudioOsdCoordinator.ownerScreenName === window.modelData.name",
            "visible: window.ownsOsd",
            "active: window.visible",
        )
        if loader_count != 1 or any(fragment not in source for fragment in osd_lifecycle):
            errors.append("Audio OSD Loader must follow AudioOsdCoordinator active owner-screen lifecycle")

    device_ipc = ROOT / "Titonium/Ipc/DeviceIpc.qml"
    bridge = ROOT / "Titonium/Orchestration/BluetoothAudioBridge.qml"
    if device_ipc.is_file():
        audio_ipc = ipc_handler_source(device_ipc.read_text(encoding="utf-8"), "audio")
        if not audio_ipc:
            errors.append("missing audio IPC handler")
        elif audio_ipc_exposes_mutation(audio_ipc):
            errors.append("Audio IPC exposes a mutating method")
        source = bridge.read_text(encoding="utf-8") if bridge.is_file() else ""
        if ("function onAudioDeviceConnected(address: string): void"
                not in source or "AudioService.requestBluetoothOutput(address)" not in source):
            errors.append("BluetoothAudioBridge must route connection intent into AudioService")


def main() -> int:
    errors: list[str] = []
    validate_audio_hardening(errors)
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
        "ClassicAudioPopupSurface 1.0 ClassicAudioPopupSurface.qml",
        "AudioOutputDeviceRow 1.0 AudioOutputDeviceRow.qml",
    ), "Audio overlay module")
    require_fragments(errors, OVERLAY_ROOT / "AudioPopupCoordinator.qml", (
        "pragma Singleton",
        "function open(screen: var, invoker = null): bool",
        "function toggle(screen: var, invoker = null): bool",
        "function close(): bool",
        "BarPopupRouting.presentation(RightPillCoordinator.presentedStyle, feature)",
        '"source": Qt.resolvedUrl(route.source)',
        '"keyboardFocus": "exclusive"',
        '"closeOnMonitorChange": true',
        '"ownerId": owner',
        '"feature": feature',
        '"barConnected": route.owner === "edge"',
        '"anchor": route.anchor',
        '"invoker": invoker',
        "BarPopupRouting.canToggle(owner, invoker, false)",
        "BarPopupRouting.existingOpenAction(owner,",
        "RightPillCoordinator.toggleConnectedSurface(owner)",
    ), "Audio popup coordinator")
    require_fragments(errors, OVERLAY_ROOT / "AudioPopupSurface.qml", (
        "TapHandler {",
        "Keys.onEscapePressed",
        "width: 380",
        "readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing",
        "anchors.topMargin: root.panelTop",
        "anchors.rightMargin: Metrics.barPadding",
        "maximumHeight: 520",
        "readonly property real availableHeight",
        "readonly property real fixedContentHeight",
        "streamList.contentHeight",
        "ListView {",
        "AudioControlRow {",
        "AudioOutputDeviceRow {",
        "AudioService.outputDevices",
        "property bool streamsExpanded: false",
        "AudioStreamRow {",
    ), "Audio popup surface")
    require_fragments(errors, OVERLAY_ROOT / "ClassicAudioPopupSurface.qml", (
        "property var descriptor:", "property var screen:", "Shared.Panel", "SurfaceManager.closeOwned",
        "Keys.onEscapePressed", "TapHandler {", "anchors.fill: parent",
        "width: 380", "readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing",
        "anchors.rightMargin: Metrics.barPadding", "AudioControlRow {", "AudioOutputDeviceRow {",
        "AudioStreamRow {",
        "property bool closing: false", "function finishClose(): void", "if (root.closing)",
        "if (Motion.reduced)", "panelExit.restart()", "transformOrigin: Item.TopRight",
        "opacity: Motion.reduced ? 1 : 0", "scale: Motion.reduced ? 1 : 0.94",
        "transform: Translate {", "id: panelEntranceOffset", "id: panelEntrance",
        "running: !Motion.reduced", "id: panelExit", "onFinished: root.finishClose()",
    ), "Classic Audio popup surface")
    classic_audio_path = OVERLAY_ROOT / "ClassicAudioPopupSurface.qml"
    if classic_audio_path.is_file() and classic_audio_path.read_text(encoding="utf-8").count(
            "SurfaceManager.closeOwned(") != 1:
        errors.append("Classic Audio popup must close exactly its frozen SurfaceManager identity")
    require_fragments(errors, OVERLAY_ROOT / "AudioSlider.qml", (
        "property real serviceValue: 0",
        "property real maximumValue: 1",
        "property bool liveUpdate: true",
        "signal userValueChanged(real value)",
        "QtControls.Slider",
        "live: root.liveUpdate",
        "onMoved:",
    ), "Audio slider")
    slider_path = OVERLAY_ROOT / "AudioSlider.qml"
    if slider_path.is_file():
        slider_source = slider_path.read_text(encoding="utf-8")
        if len(re.findall(r"\bactiveFocusOnTab\s*:", slider_source)) != 1:
            errors.append("Audio slider must expose exactly one tab stop on the inner Slider")

    popup_path = OVERLAY_ROOT / "AudioPopupSurface.qml"
    if popup_path.is_file():
        popup_source = popup_path.read_text(encoding="utf-8")
        if "Math.max(160" in popup_source:
            errors.append("Audio popup must not force a 160px minimum beyond available screen height")
        if re.search(r"ColumnLayout\s*\{[\s\S]*?anchors\.margins\s*:", popup_source):
            errors.append("Audio popup content must rely on Panel padding without nested margins")
        if not re.search(
                r"fixedContentHeight\s*\+\s*root\.streamHeight\s*"
                r"\+\s*2\s*\*\s*panel\.padding", popup_source):
            errors.append("Audio popup height must include both Panel padding edges")
        if not re.search(
                r"fixedContentHeight\s*-\s*2\s*\*\s*panel\.padding", popup_source):
            errors.append("Audio stream cap must reserve both Panel padding edges")
    require_fragments(errors, OVERLAY_ROOT / "AudioControlRow.qml", (
        'property string kind: "output"',
        "AudioService.setOutputVolume",
        "AudioService.toggleOutputMute",
        "AudioService.setInputVolume",
        "AudioService.toggleInputMute",
        'I18n.tr(root.muted ? "audio.unmute.accessible" : "audio.mute.accessible", {',
        '"name": root.label',
    ), "Audio control row")
    require_fragments(errors, OVERLAY_ROOT / "AudioOutputDeviceRow.qml", (
        "required property var device",
        "AudioService.selectOutputDevice(root.device.id)",
        "checked: root.device?.selected === true",
        'root.checked ? "radio_button_checked" : "radio_button_unchecked"',
        'I18n.tr("audio.output.select.accessible", {',
    ), "Audio output device row")
    output_device_source = (OVERLAY_ROOT / "AudioOutputDeviceRow.qml").read_text(
        encoding="utf-8")
    if 'root.checked ? "check_circle"' in output_device_source:
        errors.append("Audio output selection must use a radio indicator, not a completion icon")
    require_fragments(errors, OVERLAY_ROOT / "AudioStreamRow.qml", (
        "required property var stream",
        "Shared.SystemIcon {",
        'sourceName: root.stream?.icon || "audio-x-generic"',
        'fallbackName: "audio-x-generic"',
        "liveUpdate: false",
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
        "model: ScreenPolicy.screens",
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
        for key in (
            "audio.mute.accessible",
            "audio.unmute.accessible",
            "audio.osd.volume",
            "audio.output.accessible.unavailable",
            "audio.output.accessible.muted",
            "audio.output.accessible.volume",
            "audio.output.devices",
            "audio.output.select.accessible",
            "audio.applications.expand.accessible",
            "audio.applications.collapse.accessible",
        ):
            if key not in strings:
                errors.append(f"{locale} catalog missing audio accessibility key: {key}")
        expected_placeholders = {
            "audio.output.accessible.unavailable": {"name"},
            "audio.output.accessible.muted": {"name"},
            "audio.output.accessible.volume": {"name", "percentage"},
        }
        for key, expected in expected_placeholders.items():
            actual = set(re.findall(r"\{([^{}]+)\}", strings.get(key, "")))
            if actual != expected:
                errors.append(f"{locale} catalog has invalid placeholders for {key}")

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
        "readonly property string audioAccessibleName",
        'I18n.tr("audio.output.accessible.unavailable"',
        'I18n.tr("audio.output.accessible.muted"',
        'I18n.tr("audio.output.accessible.volume"',
        "accessibleName: root.audioAccessibleName",
        "AudioPopupCoordinator.toggle(root.screen, audioButton)",
        "AudioService.adjustOutputVolume",
        "WheelHandler {",
    ), "Connectivity pill")
    require_fragments(errors, ROOT / "Titonium/Ipc/DeviceIpc.qml", (
        "import qs.Titonium.Overlays.Audio",
        '";outputs=" + AudioService.outputDevices.length',
        "function popup(): string",
        "function closePopup(): string",
        "function popupState(): string",
        "import qs.Titonium.Osd.Audio",
        "function osdState(): string",
        "AudioOsdCoordinator.active",
        "AudioOsdCoordinator.ownerScreenName",
        "AudioPopupCoordinator.open(screen)",
        "AudioPopupCoordinator.close()",
    ), "Audio IPC adapter")
    require_fragments(errors, ROOT / "Titonium/App.qml", (
        "AudioOsdHost {}", "DeviceIpc {}",
    ), "App audio composition")
    require_fragments(errors, ROOT / "Titonium/Orchestration/SurfaceRouter.qml", (
        "function onOpened(ownerId: string, descriptor: var, screen: var): void",
        "CenterNotchCoordinator.close()",
    ), "surface routing")

    if errors:
        print("FAIL audio contract")
        print("\n".join(errors))
        return 1
    print("PASS audio contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
