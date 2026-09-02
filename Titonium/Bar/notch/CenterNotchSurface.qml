pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Theme

FocusScope {
    id: root
    required property ShellScreen screenModel
    readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing
    readonly property real notchWidth: Math.min(760, root.width - 32)
    readonly property real notchHeight: Math.min(
        440, root.height - root.panelTop - Metrics.barPadding)
    property bool closing: false
    property bool closeRequested: false
    signal closeAnimationFinished()

    anchors.fill: parent
    focus: true

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    function beginClose(): void {
        if (root.closing)
            return;
        root.closing = true;
        notchExit.restart();
    }

    onCloseRequestedChanged: {
        if (root.closeRequested)
            root.beginClose();
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(notch, eventPoint.position)
                        && !CenterNotchCoordinator.pinned)
                    CenterNotchCoordinator.close();
            }
        }
    }

    // Approved cubic baseline (2026-09-03): opacity 0->1/160ms,
    // scale 0.96->1/220ms with [0.22, 1.08, 0.36, 1, 1, 1], y -8->0/220ms.
    CenterNotch {
        id: notch
        width: root.notchWidth
        height: root.notchHeight
        anchors.top: parent.top
        anchors.topMargin: root.panelTop
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: Motion.reduced ? 1 : 0
        transformOrigin: Item.Top
        scale: Motion.reduced ? 1 : 0.93
        transform: Translate {
            id: notchEntranceOffset
            y: Motion.reduced ? 0 : -14
        }
    }

    ParallelAnimation {
        id: notchEntrance
        running: !Motion.reduced

        NumberAnimation {
            target: notch
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: notch
            property: "scale"
            from: 0.93
            to: 1
            duration: 280
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 1.22, 0.64, 1, 1, 1]
        }
        NumberAnimation {
            target: notchEntranceOffset
            property: "y"
            from: -14
            to: 0
            duration: 280
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 1.22, 0.64, 1, 1, 1]
        }
        SequentialAnimation {
            PauseAnimation { duration: 30 }
            ScriptAction { script: notch.entranceRequested = true }
        }
    }

    ParallelAnimation {
        id: notchExit

        NumberAnimation {
            target: notch
            property: "opacity"
            from: 1
            to: 0
            duration: 120
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: notch
            property: "scale"
            from: 1
            to: 0.97
            duration: 140
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: notchEntranceOffset
            property: "y"
            from: 0
            to: -8
            duration: 140
            easing.type: Easing.InCubic
        }
        onFinished: root.closeAnimationFinished()
    }

    Keys.onEscapePressed: event => {
        CenterNotchCoordinator.close();
        event.accepted = true;
    }

    Component.onCompleted: notch.forceActiveFocus(Qt.PopupFocusReason)
}
