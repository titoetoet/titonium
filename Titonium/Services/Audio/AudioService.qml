pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center
import "AudioRules.js" as AudioRules

QtObject {
    id: root

    readonly property var outputNode: Pipewire.defaultAudioSink
    readonly property var inputNode: Pipewire.defaultAudioSource
    readonly property bool ready: Pipewire.ready
    readonly property bool allowAmplification: Preferences.allowAudioAmplification
    readonly property real maximumOutputVolume:
        AudioRules.maximumOutput(root.allowAmplification)
    readonly property int invalidVolumeWarningLimit: 3

    property var previousPresentation: ({})
    property string previousOutputName: ""
    property string previousInputName: ""
    property string pendingBluetoothAddress: ""
    property var invalidVolumeWarningCounts: ({ "output": 0, "input": 0, "stream": 0 })
    property PwObjectTracker tracker: PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => node?.audio !== null)
    }

    readonly property bool outputAvailable: root.nodeUsable(root.outputNode)
    readonly property string outputName: root.outputAvailable
        ? root.nodeName(root.outputNode, I18n.tr("audio.output")) : I18n.tr("audio.unavailable")
    readonly property string outputIcon:
        AudioRules.volumeIcon(root.outputAvailable, root.outputMuted, root.outputVolume)
    readonly property real outputVolume: root.audioVolume(root.outputNode, true)
    readonly property bool outputMuted:
        root.outputAvailable && root.outputNode.audio.muted === true

    readonly property bool inputAvailable: root.nodeUsable(root.inputNode)
    readonly property string inputName: root.inputAvailable
        ? root.nodeName(root.inputNode, I18n.tr("audio.microphone")) : I18n.tr("audio.unavailable")
    readonly property real inputVolume: root.audioVolume(root.inputNode, false)
    readonly property bool inputMuted: root.inputAvailable && root.inputNode.audio.muted === true

    readonly property var audioNodeFacts: Pipewire.nodes.values.map(node => ({
        id: node?.id,
        ready: node?.ready === true,
        isSink: node?.isSink === true,
        isStream: node?.isStream === true,
        audio: node?.audio ? ({
            volume: node.audio.volume,
            muted: node.audio.muted === true,
        }) : null,
        description: node?.description || "",
        nickname: node?.nickname || "",
        name: node?.name || "",
        properties: node?.properties || ({}),
    }))
    readonly property var playbackStreams:
        AudioRules.normalizedStreams(root.audioNodeFacts,
            I18n.tr("audio.stream.fallback"), root.ready)
    readonly property var outputDevices: root.ready
        ? AudioRules.normalizedOutputDevices(root.audioNodeFacts,
            root.outputNode?.id, I18n.tr("audio.output")) : []

    signal outputPresentationChanged(real volume, bool muted)

    function nodeUsable(node: var): bool {
        return root.ready === true && node !== null && node !== undefined && node.ready === true
            && node.audio !== null && node.audio !== undefined;
    }

    function nodeName(node: var, fallback: string): string {
        return node?.description || node?.nickname || node?.name || fallback;
    }

    function audioVolume(node: var, output: bool): real {
        if (!root.nodeUsable(node))
            return 0;
        const volume = output ? AudioRules.clampOutput(node.audio.volume, root.allowAmplification)
            : AudioRules.clampUnit(node.audio.volume);
        return volume === null ? 0 : volume;
    }

    function nodeForId(nodeId: int): var {
        if (!Number.isInteger(nodeId))
            return null;
        const nodes = Pipewire.nodes.values || [];
        for (let index = 0; index < nodes.length; index++) {
            if (nodes[index]?.id === nodeId)
                return nodes[index];
        }
        return null;
    }

    function mutableNode(nodeId: int): var {
        const node = root.nodeForId(nodeId);
        return root.nodeUsable(node) ? node : null;
    }

    function warnInvalidVolume(target: string): void {
        const count = root.invalidVolumeWarningCounts[target] || 0;
        if (count >= root.invalidVolumeWarningLimit)
            return;
        root.invalidVolumeWarningCounts[target] = count + 1;
        Logger.warn("audio", "ignored invalid " + target + " volume");
    }

    function setOutputVolume(value: real): bool {
        const next = AudioRules.clampOutput(value, root.allowAmplification);
        if (next === null) {
            root.warnInvalidVolume("output");
            return false;
        }
        const node = root.mutableNode(root.outputNode?.id);
        if (node === null)
            return false;
        node.audio.volume = next;
        return true;
    }

    function adjustOutputVolume(delta: real): bool {
        const next = AudioRules.adjustOutput(root.outputVolume, delta, root.allowAmplification);
        if (next === null) {
            root.warnInvalidVolume("output");
            return false;
        }
        return root.setOutputVolume(next);
    }

    function toggleOutputMute(): bool {
        const node = root.mutableNode(root.outputNode?.id);
        if (node === null)
            return false;
        node.audio.muted = node.audio.muted !== true;
        return true;
    }

    function setInputVolume(value: real): bool {
        const next = AudioRules.clampUnit(value);
        if (next === null) {
            root.warnInvalidVolume("input");
            return false;
        }
        const node = root.mutableNode(root.inputNode?.id);
        if (node === null)
            return false;
        node.audio.volume = next;
        return true;
    }

    function toggleInputMute(): bool {
        const node = root.mutableNode(root.inputNode?.id);
        if (node === null)
            return false;
        node.audio.muted = node.audio.muted !== true;
        return true;
    }

    function selectOutputDevice(nodeId: int): bool {
        const node = root.mutableNode(nodeId);
        if (node === null || !AudioRules.isOutputDevice(node))
            return false;
        Pipewire.preferredDefaultAudioSink = node;
        return true;
    }

    function setStreamVolume(nodeId: int, value: real): bool {
        const next = AudioRules.clampUnit(value);
        if (next === null) {
            root.warnInvalidVolume("stream");
            return false;
        }
        const node = root.mutableNode(nodeId);
        if (node === null || !AudioRules.isPlaybackStream(node))
            return false;
        node.audio.volume = next;
        return true;
    }

    function toggleStreamMute(nodeId: int): bool {
        const node = root.mutableNode(nodeId);
        if (node === null || !AudioRules.isPlaybackStream(node))
            return false;
        node.audio.muted = node.audio.muted !== true;
        return true;
    }

    function requestBluetoothOutput(address: string): bool {
        const normalized = AudioRules.normalizedBluetoothAddress(address);
        if (!normalized)
            return false;
        root.pendingBluetoothAddress = normalized;
        return root.trySelectPendingBluetoothOutput();
    }

    function trySelectPendingBluetoothOutput(): bool {
        if (!root.pendingBluetoothAddress)
            return false;
        const sink = AudioRules.bluetoothSinkFor(Pipewire.nodes.values || [],
            root.pendingBluetoothAddress);
        if (sink === null)
            return false;
        Pipewire.preferredDefaultAudioSink = sink;
        root.pendingBluetoothAddress = "";
        return true;
    }

    function observeCenterDeviceChanges(): void {
        const output = root.outputName;
        const input = root.inputName;
        if (root.previousOutputName.length > 0 && output !== root.previousOutputName) {
            CenterAttentionService.publish({
                id: "audio:output", source: "audio", kind: "output_changed",
                title: I18n.tr("audio.center.output_changed", { "name": output }),
                icon: "volume_up"
            });
        }
        if (root.previousInputName.length > 0 && input !== root.previousInputName) {
            CenterAttentionService.publish({
                id: "audio:input", source: "audio", kind: "input_changed",
                title: I18n.tr("audio.center.input_changed", { "name": input }),
                icon: "mic"
            });
        }
        root.previousOutputName = output;
        root.previousInputName = input;
    }

    function syncCenterIndicators(): void {
        root.observeCenterDeviceChanges();
        CenterAttentionService.setIndicator(
            "audio-output", root.outputIcon,
            I18n.tr("audio.output"), root.outputAvailable && root.outputMuted);
        CenterAttentionService.setIndicator(
            "audio-microphone", root.inputMuted ? "mic_off" : "mic",
            I18n.tr("audio.microphone"), root.inputAvailable && root.inputMuted);
        CenterAttentionService.setIndicator(
            "audio-streams", "graphic_eq",
            I18n.tr("audio.playback_streams"), root.playbackStreams.length > 0);
    }

    function observeOutputPresentation(): void {
        const event = AudioRules.presentationEvent(root.previousPresentation, {
            key: root.outputNode?.id === undefined ? "" : String(root.outputNode.id),
            available: root.outputAvailable,
            volume: root.outputVolume,
            muted: root.outputMuted,
        });
        root.previousPresentation = event.next;
        if (event.emit) {
            root.outputPresentationChanged(event.next.volume, event.next.muted);
            CenterAttentionService.publish({
                id: "audio:volume", source: "audio", kind: "volume_changed",
                title: I18n.tr("audio.center.volume_changed", {
                    "value": Math.round(event.next.volume * 100)
                }),
                icon: root.outputIcon
            });
        }
        root.syncCenterIndicators();
    }

    function resetOutputPresentation(): void {
        root.previousPresentation = null;
        root.observeOutputPresentation();
    }

    function onOutputAvailableChanged(): void { root.resetOutputPresentation(); }

    property Connections pipewireConnections: Connections {
        target: Pipewire

        function onDefaultAudioSinkChanged(): void { root.resetOutputPresentation(); }
        function onReadyChanged(): void { root.resetOutputPresentation(); }
    }

    property Connections outputAudioConnections: Connections {
        target: root.outputNode?.audio || null

        function onVolumesChanged(): void { root.observeOutputPresentation(); }
        function onMutedChanged(): void { root.observeOutputPresentation(); }
    }

    property Connections trackerConnections: Connections {
        target: root.tracker
        // function onObjectsChanged(): void { root.trySelectPendingBluetoothOutput(); }
        function onObjectsChanged(): void { root.trySelectPendingBluetoothOutput(); root.syncCenterIndicators(); }
    }

    Component.onCompleted: {
        root.resetOutputPresentation();
        root.syncCenterIndicators();
    }
}
