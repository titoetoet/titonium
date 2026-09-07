pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Titonium.Services.Notifications
import qs.Titonium.Core.Runtime
import "CaptureFeedbackRules.js" as Rules

QtObject {
    id: root
    property var state: Rules.initialState()
    readonly property var feedback: root.state.feedback
    readonly property var contexts: Rules.contexts(root.state).map(item => Object.freeze(
        Object.assign({}, item, {title: I18n.tr("capture.screenshot_saved")})))
    property string scheduledId: ""
    property double observedRecordingStart: 0
    function select(contextId: string): void { root.state = Rules.select(root.state, contextId); }
    function publish(event: var): void {
        const next = Rules.publish(root.state, event);
        if (next === root.state) return;
        root.state = next;
        root.schedule();
    }
    function schedule(): void {
        expiry.stop();
        root.scheduledId = root.feedback?.id || "";
        if (!root.feedback) return;
        expiry.interval = Math.max(1, root.feedback.expiresAt - Date.now());
        expiry.start();
    }
    function syncRecording(): void {
        if (!ScreenRecordService.recording) {
            root.observedRecordingStart = 0;
            if (root.feedback?.kind === "recording_started") {
                root.state = Rules.expire(root.state, root.feedback.id, root.feedback.expiresAt);
                root.schedule();
            }
            return;
        }
        if (root.observedRecordingStart === ScreenRecordService.startedAt) return;
        root.observedRecordingStart = ScreenRecordService.startedAt;
        root.publish(Rules.recording(root.observedRecordingStart, Date.now()));
    }
    property Timer expiry: Timer {
        repeat: false
        onTriggered: {
            root.state = Rules.expire(root.state, root.scheduledId, Date.now());
            root.schedule();
        }
    }
    property Connections notifications: Connections {
        target: NotificationService
        function onDescriptorPublished(descriptor: var): void {
            root.publish(Rules.screenshot(descriptor, Date.now(),
                Quickshell.env("HOME") + "/Pictures/Screenshots"));
        }
    }
    property Connections recording: Connections {
        target: ScreenRecordService
        function onRecordingChanged(): void { Qt.callLater(root.syncRecording); }
        function onStartedAtChanged(): void { Qt.callLater(root.syncRecording); }
    }
    Component.onCompleted: Qt.callLater(root.syncRecording)
}
