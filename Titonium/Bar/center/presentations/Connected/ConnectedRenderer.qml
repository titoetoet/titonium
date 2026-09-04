pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root
    required property var snapshot
    required property var viewState
    required property var profile
    signal intentRequested(var intent)
    signal transitionFinished(int generation)
    readonly property var context: root.snapshot.contexts.find(
        item => item.id === root.viewState.selectedContextId) || root.snapshot.primary
    readonly property var contextActions: root.snapshot.capabilities.actions.filter(
        item => root.context && item.contextId === root.context.id)
    readonly property real shoulderSize: 18
    readonly property real visualWidth: root.viewState.mode === "expanded"
        ? Math.min(720, parent.width - 40)
        : (root.viewState.mode === "banner" ? Math.min(480, parent.width - 24) : 220)
    readonly property real bodyWidth: Math.max(1, root.visualWidth - root.shoulderSize * 2)
    readonly property real bodyHeight: root.viewState.mode === "expanded" ? 440
        : (root.viewState.mode === "banner" ? 72 : root.profile.compact.height)
    readonly property real bodyRadius: root.viewState.mode === "expanded"
        ? root.profile.expanded.radius : (root.viewState.mode === "banner"
        ? root.profile.banner.radius : root.profile.compact.radius)
    readonly property rect visualBounds: Qt.rect(shape.x, shape.y, shape.width, shape.height)
    readonly property rect interactiveBounds: root.visualBounds

    Shared.ConnectedPillShape {
        id: shape
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        bodyWidth: root.bodyWidth
        bodyHeight: root.bodyHeight
        shoulderSize: root.shoulderSize
        bottomRadius: root.bodyRadius
        color: Theme.light ? "#ffffff" : "#000000"

        Item {
            x: shape.bodyLeft
            width: shape.bodyWidth
            height: shape.bodyHeight

            ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - 32)
            spacing: Metrics.spacingSmall

            RowLayout {
                Layout.fillWidth: true
                Shared.SystemIcon {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    sourceName: root.context?.icon || ""
                    fallbackName: root.context?.icon || "center_focus_strong"
                    size: 18
                }
                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: root.context?.title || "Center"
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                visible: root.viewState.mode !== "compact" && (root.context?.subtitle || "").length > 0
                text: root.context?.subtitle || ""
                variant: "caption"
                tone: "secondary"
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: root.viewState.mode !== "compact" && root.contextActions.length > 0
                spacing: Metrics.spacingSmall
                Repeater {
                    model: root.contextActions
                    Shared.Button {
                        required property var modelData
                        size: "small"
                        variant: modelData.role === "primary" ? "primary" : "quiet"
                        iconName: modelData.icon
                        accessibleName: modelData.label
                        enabled: modelData.enabled
                        onTriggered: root.intentRequested({ type: "invoke-action",
                            actionId: modelData.id, contextId: modelData.contextId })
                    }
                }
            }
            }
        }
        TapHandler {
            onTapped: root.intentRequested({ type: "request-mode",
                mode: root.viewState.mode === "expanded" ? "compact" : "expanded" })
        }
        Behavior on bodyWidth { NumberAnimation { duration: Motion.reduced ? 0 : 240 } }
        Behavior on bodyHeight {
            NumberAnimation {
                duration: Motion.reduced ? 0 : 240
                onFinished: root.transitionFinished(root.viewState.generation)
            }
        }
    }
}
