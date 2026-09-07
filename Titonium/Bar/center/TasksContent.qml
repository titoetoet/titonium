pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root
    required property var snapshot
    required property var viewState
    signal intentRequested(var intent)
    readonly property var session: FocusSessionService.session
    readonly property var activities: (root.snapshot?.contexts || []).filter(item => item.source === "job" || item.source === "timer")
    property double displayNow: Date.now()
    readonly property int secondsRemaining: root.session ? Math.max(0, Math.ceil((root.session.deadline - root.displayNow) / 1000)) : 0
    implicitHeight: content.implicitHeight + Metrics.spacingLarge * 2
    Timer {
        interval: 1000; repeat: true
        running: root.visible && !!root.session
        onTriggered: root.displayNow = Date.now()
    }
    onSessionChanged: root.displayNow = Date.now()
    ColumnLayout {
        id: content
        x: Metrics.spacingLarge; y: Metrics.spacingLarge
        width: Math.max(0, root.width - Metrics.spacingLarge * 2)
        spacing: Metrics.spacingMedium
        Shared.TextLabel { text: I18n.tr("center.expanded.today_focus"); variant: "titleSmall" }
        Shared.TextLabel {
            Layout.fillWidth: true
            text: CenterFocusStore.text || I18n.tr("center.expanded.focus_empty")
            wrapMode: Text.Wrap
        }
        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("center.expanded.focus_source") + "\n" + CenterFocusStore.focusPath
            tone: "secondary"; variant: "caption"; wrapMode: Text.WrapAnywhere
        }
        Shared.TextLabel {
            visible: !!root.session
            text: Math.floor(root.secondsRemaining / 60) + ":" + String(root.secondsRemaining % 60).padStart(2, "0")
            variant: "display"
            font.features: ({"tnum": 1})
        }
        Shared.Button {
            objectName: "focusSessionAction"
            label: I18n.tr(root.session ? "center.expanded.focus_cancel" : "center.expanded.focus_start")
            onTriggered: {
                if (FocusSessionService.session)
                    FocusSessionService.cancel();
                else
                    FocusSessionService.start(25 * 60);
            }
        }
        Shared.TextLabel { text: I18n.tr("center.expanded.tasks_activity"); variant: "titleSmall" }
        Shared.TextLabel {
            Layout.fillWidth: true
            visible: root.activities.length === 0
            text: I18n.tr("center.expanded.tasks_empty")
            tone: "secondary"; wrapMode: Text.Wrap
        }
        Repeater {
            model: root.activities
            ColumnLayout {
                id: activity
                required property var modelData
                Layout.fillWidth: true
                Shared.TextLabel {
                    Layout.fillWidth: true; text: activity.modelData.title; wrapMode: Text.Wrap
                    tone: activity.modelData.id === root.viewState?.selectedContextId ? "accent" : "primary"
                }
                Shared.TextLabel {
                    visible: activity.modelData.progress !== null && activity.modelData.progress !== undefined
                    text: Math.round((activity.modelData.progress || 0) * 100) + "%"
                    tone: "secondary"
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingSmall
                    Repeater {
                        model: (root.snapshot?.capabilities?.actions || []).filter(action => action.contextId === activity.modelData.id)
                        Shared.Button {
                            required property var modelData
                            label: modelData.label; enabled: modelData.enabled
                            variant: modelData.role === "destructive" ? "danger" : "secondary"
                            onTriggered: root.intentRequested({type: "invoke-action", actionId: modelData.id, contextId: activity.modelData.id})
                        }
                    }
                }
            }
        }
    }
}
