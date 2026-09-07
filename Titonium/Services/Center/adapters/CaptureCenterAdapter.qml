pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Capture
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Audio

QtObject {
    id: root
    readonly property string recordingContextId: "capture:recording:" + ScreenRecordService.startedAt
    readonly property var recordingContexts: ScreenRecordService.recording ? Object.freeze([Object.freeze({
        id: root.recordingContextId, source: "capture", kind: "screen-recording",
        title: "REC", subtitle: Math.floor(ScreenRecordService.elapsedSeconds) + "s",
        icon: "screen_record", tone: "critical", attention: "ambient",
        progress: null, occurredAt: ScreenRecordService.startedAt,
        expiresAt: 0, details: Object.freeze({}), actionIds: Object.freeze(["capture.stop"])
    })]) : Object.freeze([])
    readonly property var contexts: Object.freeze(root.recordingContexts.concat(CaptureFeedbackService.contexts, AudioService.captureStreams.map(item => Object.freeze({
        id: "capture:mic:" + item.key, source: "capture", kind: "microphone",
        title: I18n.tr("audio.microphone"), subtitle: item.title, icon: "mic", tone: "critical", attention: "ambient",
        progress: null, occurredAt: item.startedAt, expiresAt: 0,
        details: Object.freeze({nodeId: item.nodeId, key: item.key}), actionIds: Object.freeze(["capture.mute"])
    }))));
    readonly property var indicators: Object.freeze([Object.freeze({
        id: "capture:recording", icon: "screen_record", accessibleName: "Screen recording",
        tone: "critical", active: ScreenRecordService.recording
    })])
    readonly property var recordingActions: ScreenRecordService.recording ? Object.freeze([Object.freeze({
        id: "capture.stop", contextId: root.recordingContextId, role: "destructive",
        label: I18n.tr("center.privacy.stop_recording"), icon: "stop_circle", enabled: ScreenRecordService.canStop
    })]) : Object.freeze([])
    readonly property var actions: Object.freeze(root.recordingActions.concat(AudioService.captureStreams.map(item => Object.freeze({
        id: "capture.mute", contextId: "capture:mic:" + item.key, role: "secondary",
        label: I18n.tr(item.muted ? "center.privacy.unmute_microphone" : "center.privacy.mute_microphone"),
        icon: item.muted ? "mic" : "mic_off", enabled: true
    }))));
    function dispatch(actionId: string, contextId: string, idempotencyKey: string): var {
        if (actionId === "capture.mute") {
            const context = root.contexts.find(item => item.id === contextId && item.kind === "microphone");
            const accepted = !!context && AudioService.toggleCaptureMute(context.details.nodeId, context.details.key);
            return Object.freeze({accepted: accepted, status: accepted ? "completed" : "stale", reason: "", closePolicy: "keep"});
        }
        if (actionId === "capture.stop" && contextId === root.recordingContextId && ScreenRecordService.recording) {
            const accepted = ScreenRecordService.stopRecording();
            return Object.freeze({ accepted: accepted, status: accepted ? "completed" : "unavailable",
                reason: "", closePolicy: "keep" });
        }
        return Object.freeze({ accepted: false, status: "stale", reason: "unknown-action",
            closePolicy: "keep" });
    }
}
