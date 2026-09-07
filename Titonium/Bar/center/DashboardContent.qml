pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root
    required property var snapshot
    required property var viewState
    signal intentRequested(var intent)
    readonly property var contexts: root.snapshot?.contexts || []
    readonly property var actions: root.snapshot?.capabilities?.actions || []
    readonly property var music: root.contexts.find(item => item.source === "media"
        && item.id === root.viewState?.selectedContextId)
        || root.contexts.find(item => item.source === "media") || null
    readonly property var selectedContext: root.contexts.find(item => item.id === root.viewState?.selectedContextId) || null
    readonly property var selectedDetail: root.selectedContext?.source !== "media" ? root.selectedContext : null
    readonly property var activities: root.contexts.filter(item => item.source !== "media"
        && item.id !== root.selectedDetail?.id)

    function invoke(actionId: string, contextId: string): void {
        const context = root.contexts.find(item => item.id === contextId);
        const action = root.actions.find(item => item.id === actionId && item.contextId === contextId);
        if (context && action?.enabled === true)
            root.intentRequested({type: "invoke-action", actionId: actionId, contextId: contextId});
    }

    implicitHeight: content.implicitHeight + Metrics.spacingLarge * 2
    ColumnLayout {
        id: content
        x: Metrics.spacingLarge; y: Metrics.spacingLarge
        width: Math.max(0, root.width - Metrics.spacingLarge * 2)
        spacing: Metrics.spacingMedium
        Loader {
            objectName: "dashboardSelectedDetail"
            Layout.fillWidth: true
            readonly property Item loadedItem: item as Item
            Layout.preferredHeight: loadedItem ? loadedItem.implicitHeight : 0
            active: !!root.selectedDetail
            visible: active
            sourceComponent: ContextCard { context: root.selectedDetail }
        }
        Shared.TextLabel {
            objectName: "dashboardContextUnavailable"
            Layout.fillWidth: true
            visible: !!root.viewState?.selectedContextId && !root.selectedContext
            text: I18n.tr("center.expanded.context_unavailable")
            tone: "secondary"; wrapMode: Text.Wrap
        }
        Shared.TextLabel {
            objectName: "dashboardMusicHeading"
            text: I18n.tr("center.expanded.music"); variant: "titleSmall"
        }
        Loader {
            Layout.fillWidth: true
            readonly property Item loadedItem: item as Item
            Layout.preferredHeight: loadedItem ? loadedItem.implicitHeight : 0
            active: !!root.music
            visible: active
            sourceComponent: MusicPlayerContent {
                context: root.music
                actions: root.actions
                onIntentRequested: intent => root.intentRequested(intent)
            }
        }
        Shared.TextLabel {
            Layout.fillWidth: true
            visible: !root.music
            text: I18n.tr("center.expanded.music_empty")
            tone: "secondary"; wrapMode: Text.Wrap
        }
        Shared.TextLabel { text: I18n.tr("center.expanded.activities"); variant: "titleSmall" }
        Shared.TextLabel {
            Layout.fillWidth: true
            visible: root.activities.length === 0
            text: I18n.tr("center.expanded.activities_empty")
            tone: "secondary"; wrapMode: Text.Wrap
        }
        Repeater {
            model: root.activities
            ContextCard {
                required property var modelData
                context: modelData
                Layout.fillWidth: true
            }
        }
    }

    component ContextCard: Rectangle {
        id: card
        required property var context
        implicitHeight: cardContent.implicitHeight + Metrics.spacingMedium * 2
        radius: Metrics.radiusMedium
        color: Theme.surfaceElevated
        border.width: context?.id === root.viewState?.selectedContextId ? 1 : 0
        border.color: Theme.accent
        ColumnLayout {
            id: cardContent
            x: Metrics.spacingMedium; y: Metrics.spacingMedium
            width: Math.max(0, parent.width - Metrics.spacingMedium * 2)
            spacing: Metrics.spacingSmall
            Shared.TextLabel {
                Layout.fillWidth: true
                text: card.context?.title || ""
                wrapMode: Text.Wrap; strong: true
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                text: card.context?.subtitle || ""
                visible: text.length > 0; wrapMode: Text.Wrap; tone: "secondary"
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                text: card.context?.details?.appName || ""
                visible: text.length > 0 && text !== card.context?.subtitle && text !== card.context?.title
                wrapMode: Text.Wrap; tone: "secondary"; variant: "caption"
            }
            Shared.TextLabel {
                objectName: "dashboardContextBody"
                Layout.fillWidth: true
                text: card.context?.details?.body || ""
                visible: text.length > 0 && text !== card.context?.subtitle && text !== card.context?.title
                wrapMode: Text.Wrap
            }
            Shared.TextLabel {
                objectName: "dashboardContextCommand"
                Layout.fillWidth: true
                text: card.context?.details?.command || ""
                visible: text.length > 0 && text !== card.context?.title && text !== card.context?.subtitle
                wrapMode: Text.WrapAnywhere; variant: "mono"
            }
            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: active ? 240 : 0
                active: card.context?.source === "capture" && card.context?.kind === "screenshot"
                visible: active
                sourceComponent: ScreenshotPreviewContent { context: card.context }
            }
            Shared.Button {
                visible: ["focus", "job", "timer"].indexOf(card.context?.source) >= 0
                label: I18n.tr("center.expanded.open_tasks")
                variant: "quiet"
                onTriggered: root.intentRequested({type: "activate-compact", contextId: card.context.id})
            }
            Flow {
                Layout.fillWidth: true
                spacing: Metrics.spacingSmall
                Repeater {
                    model: root.actions.filter(action => action.contextId === card.context?.id)
                    Shared.Button {
                        required property var modelData
                        objectName: "dashboardAction_" + modelData.id
                        label: modelData.label; enabled: modelData.enabled === true
                        variant: modelData.role === "destructive" ? "danger"
                            : modelData.role === "primary" ? "primary" : "secondary"
                        onTriggered: root.invoke(modelData.id, card.context.id)
                    }
                }
            }
        }
    }
}
