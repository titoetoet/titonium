pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.Titonium.Core.Runtime
import "AudioRules.js" as AudioRules

QtObject {
    id: root

    readonly property var outputNode: Pipewire.defaultAudioSink
    readonly property var inputNode: Pipewire.defaultAudioSource
    readonly property bool ready: Pipewire.ready
    readonly property bool allowAmplification: Preferences.allowAudioAmplification
    readonly property real maximumOutputVolume:
        AudioRules.maximumOutput(root.allowAmplification)

    property var previousPresentation: ({})
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

    readonly property var playbackStreams:
        AudioRules.normalizedStreams(Pipewire.nodes.values, I18n.tr("audio.stream.fallback"))

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

    function setOutputVolume(value: real): bool {
        const next = AudioRules.clampOutput(value, root.allowAmplification);
        const node = root.mutableNode(root.outputNode?.id);
        if (next === null || node === null)
            return false;
        node.audio.volume = next;
        return true;
    }

    function adjustOutputVolume(delta: real): bool {
        const next = AudioRules.adjustOutput(root.outputVolume, delta, root.allowAmplification);
        return next === null ? false : root.setOutputVolume(next);
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
        const node = root.mutableNode(root.inputNode?.id);
        if (next === null || node === null)
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

    function setStreamVolume(nodeId: int, value: real): bool {
        const next = AudioRules.clampUnit(value);
        const node = root.mutableNode(nodeId);
        if (next === null || node === null || !AudioRules.isPlaybackStream(node))
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

    function observeOutputPresentation(): void {
        const event = AudioRules.presentationEvent(root.previousPresentation, {
            key: root.outputNode?.id === undefined ? "" : String(root.outputNode.id),
            available: root.outputAvailable,
            volume: root.outputVolume,
            muted: root.outputMuted,
        });
        root.previousPresentation = event.next;
        if (event.emit)
            root.outputPresentationChanged(event.next.volume, event.next.muted);
    }

    function resetOutputPresentation(): void {
        root.previousPresentation = null;
        root.observeOutputPresentation();
    }

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

    Component.onCompleted: root.resetOutputPresentation()
}
