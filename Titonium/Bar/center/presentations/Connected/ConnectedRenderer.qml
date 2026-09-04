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
    readonly property rect visualBounds: Qt.rect(body.x, body.y, body.width, body.height)
    readonly property rect interactiveBounds: root.visualBounds

    Rectangle {
        id: body
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.viewState.mode === "expanded" ? Math.min(720, parent.width - 40)
            : (root.viewState.mode === "banner" ? Math.min(480, parent.width - 24) : 220)
        height: root.viewState.mode === "expanded" ? 440
            : (root.viewState.mode === "banner" ? 72 : root.profile.compact.height)
        radius: root.viewState.mode === "expanded" ? root.profile.expanded.radius
            : (root.viewState.mode === "banner" ? root.profile.banner.radius
            : root.profile.compact.radius)
        color: Theme.light ? "#ffffff" : "#000000"

        RowLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - 32)
            spacing: Metrics.spacingSmall
            Shared.Icon { name: root.context?.icon || "center_focus_strong"; size: 18 }
            Shared.TextLabel {
                Layout.fillWidth: true
                text: root.context?.title || "Center"
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }
        TapHandler {
            onTapped: root.intentRequested({ type: "request-mode",
                mode: root.viewState.mode === "expanded" ? "compact" : "expanded" })
        }
        Behavior on width { NumberAnimation { duration: Motion.reduced ? 0 : 240 } }
        Behavior on height {
            NumberAnimation {
                duration: Motion.reduced ? 0 : 240
                onFinished: root.transitionFinished(root.viewState.generation)
            }
        }
    }
}
