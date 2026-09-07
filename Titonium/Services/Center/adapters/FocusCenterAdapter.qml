pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Center
import qs.Titonium.Core.Runtime

QtObject {
    readonly property var contexts: FocusSessionService.session ? Object.freeze([Object.freeze({
        id: "focus:session", source: "focus", kind: "pomodoro", title: I18n.tr("center.compact.focus"),
        subtitle: "", icon: "center_focus_strong", tone: "normal", attention: "ambient",
        progress: null, occurredAt: FocusSessionService.session.startedAt,
        expiresAt: FocusSessionService.session.deadline,
        details: FocusSessionService.session, actionIds: Object.freeze([])
    })]) : Object.freeze([Object.freeze({
        id: "focus:daily", source: "focus", kind: "daily", title: CenterFocusStore.text,
        subtitle: "", icon: "center_focus_strong", tone: "normal", attention: "ambient",
        progress: null, occurredAt: CenterFocusStore.focusModifiedAt || 0, expiresAt: 0,
        details: Object.freeze({}), actionIds: Object.freeze([])
    })])
    readonly property var indicators: Object.freeze([])
    readonly property var actions: Object.freeze([])
    function dispatch(actionId: string, contextId: string, idempotencyKey: string): var {
        return Object.freeze({ accepted: false, status: "stale", reason: "unknown-action",
            closePolicy: "keep" });
    }
}
