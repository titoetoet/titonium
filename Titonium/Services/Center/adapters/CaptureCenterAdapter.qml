pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Capture

QtObject {
    readonly property var contexts: ScreenRecordService.recording ? Object.freeze([Object.freeze({
        id: "capture:recording", source: "capture", kind: "screen-recording",
        title: "REC", subtitle: Math.floor(ScreenRecordService.elapsedSeconds) + "s",
        icon: "screen_record", tone: "critical", attention: "ambient",
        progress: null, occurredAt: ScreenRecordService.startedAt,
        expiresAt: 0, details: Object.freeze({}), actionIds: Object.freeze([])
    })]) : Object.freeze([])
    readonly property var indicators: Object.freeze([Object.freeze({
        id: "capture:recording", icon: "screen_record", accessibleName: "Screen recording",
        tone: "critical", active: ScreenRecordService.recording
    })])
    readonly property var actions: Object.freeze([])
    function dispatch(actionId: string, contextId: string, idempotencyKey: string): var {
        return Object.freeze({ accepted: false, status: "stale", reason: "unknown-action",
            closePolicy: "keep" });
    }
}
