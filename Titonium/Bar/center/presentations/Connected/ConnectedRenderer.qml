pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Bar.center
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root
    required property var snapshot
    required property var viewState
    required property var profile
    signal intentRequested(var intent)
    signal transitionFinished(int generation)
    readonly property bool popup: root.viewState.mode === "banner" || root.viewState.mode === "expanded"
    readonly property var context: root.viewState.previewContext || root.snapshot.contexts.find(
        item => item.id === root.viewState.selectedContextId) || null
    readonly property real shoulderSize: 18
    readonly property real headerHeight: compactCapsule.y + compactCapsule.height + 12
    readonly property real bodyWidth: Math.max(1, Math.min(root.viewState.mode === "expanded" ? 720 : 480,
        root.width - 40 - root.shoulderSize * 2))
    readonly property real bodyHeight: Math.max(1, Math.min(
        root.headerHeight + (root.viewState.mode === "expanded" ? 500 : 88), root.height - 16))
    readonly property rect visualBounds: root.popup
        ? Qt.rect(shape.x, shape.y, shape.width, shape.height) : compactCapsule.visualBounds
    readonly property rect interactiveBounds: root.visualBounds

    Shared.ConnectedPillShape {
        id: shape
        objectName: "connectedCenterShell"
        visible: root.popup
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        bodyWidth: root.popup ? root.bodyWidth : compactCapsule.width
        bodyHeight: root.popup ? root.bodyHeight : compactCapsule.height + 4
        shoulderSize: root.shoulderSize
        bottomRadius: root.viewState.mode === "expanded" ? root.profile.expanded.radius : root.profile.banner.radius
        color: Theme.centerSurface
        Loader {
            x: shape.bodyLeft + 8
            y: root.headerHeight
            width: Math.max(0, shape.bodyWidth - 16)
            height: Math.max(0, shape.bodyHeight - y - 8)
            clip: true
            active: root.visible && root.viewState.mode === "banner"
            sourceComponent: Component {
                NormalBannerContent {
                    context: root.context
                    onIntentRequested: intent => root.intentRequested(intent)
                }
            }
        }
        Loader {
            objectName: "connectedExpandedContent"
            x: shape.bodyLeft + 8
            y: root.headerHeight
            width: Math.max(0, shape.bodyWidth - 16)
            height: Math.max(0, shape.bodyHeight - y - 8)
            clip: true
            active: root.visible && root.viewState.mode === "expanded"
            sourceComponent: Component {
                ExpandedContent {
                    snapshot: root.snapshot
                    viewState: root.viewState
                    onIntentRequested: intent => root.intentRequested(intent)
                }
            }
        }
        Behavior on bodyWidth { NumberAnimation { duration: Motion.reduced ? 0 : Motion.normal; easing.type: Easing.OutCubic } }
        Behavior on bodyHeight {
            NumberAnimation {
                duration: Motion.reduced ? 0 : Motion.normal
                easing.type: Easing.OutCubic
                onFinished: root.transitionFinished(root.viewState.generation)
            }
        }
    }
    CenterCompactCapsule {
        id: compactCapsule
        objectName: "connectedCenterTitle"
        connected: true
        visible: root.viewState.mode !== "closed"
        z: 2
        backgroundVisible: !root.popup
        color: Theme.legacy && root.popup ? Theme.surfaceElevated : "transparent"
        border.width: Theme.legacy && root.popup ? Metrics.borderWidth : 0
        border.color: Theme.border
        interactionEnabled: root.viewState.mode === "compact"
        anchors.horizontalCenter: parent.horizontalCenter
        y: 4
        snapshot: root.snapshot
        monitorWidth: root.width
        onIntentRequested: intent => root.intentRequested(intent)
    }
    onViewStateChanged: {
        if (Motion.reduced || !root.popup) {
            const generation = root.viewState.generation;
            Qt.callLater(() => root.transitionFinished(generation));
        }
    }
}
