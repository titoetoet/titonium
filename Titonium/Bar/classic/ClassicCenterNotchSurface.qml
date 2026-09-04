pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Bar.notch
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    required property ShellScreen screenModel
    property bool closeRequested: false
    property bool closing: false
    signal bannerRequested(var screen, var context, bool autoDismiss)
    signal settingsRequested(var screen)
    signal closeAnimationFinished()

    readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing
    readonly property real expandedWidth: Math.min(720, Math.max(320, root.width - 40))
    readonly property real bannerWidth: Math.min(480, Math.max(280, root.width - 40))
    readonly property real dragProgress: CenterNotchCoordinator.dragProgress
    readonly property bool banner: CenterNotchCoordinator.requestedPage === "banner"
    readonly property real panelWidth: root.banner
        ? root.bannerWidth + (root.expandedWidth - root.bannerWidth) * root.dragProgress
        : root.expandedWidth
    readonly property real panelHeight: Math.min(
        root.banner ? 72 + (440 - 72) * root.dragProgress : 440,
        Math.max(72, root.height - root.panelTop - Metrics.barPadding))

    anchors.fill: parent
    focus: true

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0
            && local.x <= item.width && local.y <= item.height;
    }

    function settleDrag(offset: real, velocity: real): void {
        const plan = CenterNotchCoordinator.finishDrag(offset, velocity);
        dragSettle.stop();
        dragSettle.from = CenterNotchCoordinator.dragProgress;
        dragSettle.to = plan.targetProgress;
        dragSettle.duration = Motion.reduced ? 0 : plan.duration;
        dragSettle.targetState = plan.targetState;
        dragSettle.start();
    }

    function beginClose(): void {
        if (root.closing)
            return;
        root.closing = true;
        notchEntrance.stop();
        if (Motion.reduced) {
            root.closeAnimationFinished();
            return;
        }
        notchExit.restart();
    }

    function reopen(): void {
        if (!root.closing)
            return;
        notchExit.stop();
        root.closing = false;
        if (!Motion.reduced)
            notchEntrance.restart();
    }

    onCloseRequestedChanged: {
        if (root.closeRequested)
            root.beginClose();
        else
            root.reopen();
    }

    NumberAnimation {
        id: dragSettle
        property string targetState: "banner"
        target: CenterNotchCoordinator
        property: "dragProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.springDamped
        onFinished: CenterNotchCoordinator.completeDragSettle(dragSettle.targetState)
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(notch, eventPoint.position))
                    CenterNotchCoordinator.collapse();
            }
        }
    }

    Shared.Panel {
        id: notch
        width: root.panelWidth
        height: root.panelHeight
        anchors.top: parent.top
        anchors.topMargin: root.panelTop
        anchors.horizontalCenter: parent.horizontalCenter
        padding: 0
        customColor: Theme.surface
        clipContent: true
        transformOrigin: Item.Top
        opacity: Motion.reduced ? 1 : 0
        scale: Motion.reduced ? 1 : 0.93
        transform: Translate {
            id: notchEntranceOffset
            y: Motion.reduced ? 0 : -14
        }

        Behavior on width {
            enabled: !root.banner || root.dragProgress <= 0
            NumberAnimation { duration: Motion.reduced ? 0 : 220; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: !root.banner || root.dragProgress <= 0
            NumberAnimation { duration: Motion.reduced ? 0 : 220; easing.type: Easing.OutCubic }
        }

        CenterNotch {
            anchors.fill: parent
            screenModel: root.screenModel
            entranceRequested: !root.closing
            closing: root.closing
            islandRadius: notch.radius
            onExpandedRequested: root.settleDrag(48, 0)
            onDragStarted: dragSettle.stop()
            onDragFinished: (offset, velocity) => root.settleDrag(offset, velocity)
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: root.settingsRequested(root.screenModel)
        }
    }

    ParallelAnimation {
        id: notchEntrance
        running: !Motion.reduced
        NumberAnimation { target: notch; property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: notch; property: "scale"; from: 0.93; to: 1; duration: 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: notchEntranceOffset; property: "y"; from: -14; to: 0; duration: 280; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: notchExit
        NumberAnimation { target: notch; property: "opacity"; from: 1; to: 0; duration: 120; easing.type: Easing.InCubic }
        NumberAnimation { target: notch; property: "scale"; from: 1; to: 0.97; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: notchEntranceOffset; property: "y"; from: 0; to: -8; duration: 140; easing.type: Easing.InCubic }
        onFinished: root.closeAnimationFinished()
    }

    Keys.onEscapePressed: event => {
        CenterNotchCoordinator.collapse();
        event.accepted = true;
    }

    Component.onCompleted: notch.forceActiveFocus(Qt.PopupFocusReason)
}
