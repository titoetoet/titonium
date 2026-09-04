pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.WindowSwitcher
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null

    anchors.fill: parent
    focus: true

    property bool closing: false

    function close(): void {
        if (root.closing)
            return;
        root.closing = true;
        if (Motion.reduced) {
            WindowSwitcherService.cancel();
        } else {
            panelExit.start();
        }
    }

    ParallelAnimation {
        id: panelExit

        NumberAnimation {
            target: backdropScrim
            property: "opacity"
            from: 0.25
            to: 0
            duration: 100
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel
            property: "opacity"
            from: 1
            to: 0
            duration: 100
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 1
            to: 0.96
            duration: 110
            easing.type: Easing.InCubic
        }
        onFinished: WindowSwitcherService.cancel()
    }

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    Rectangle {
        id: backdropScrim
        anchors.fill: parent
        color: "#000000"
        opacity: Motion.reduced ? 0.25 : 0

        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(panel, eventPoint.position))
                    root.close();
            }
        }
    }

    ParallelAnimation {
        id: panelEntrance
        running: !Motion.reduced

        NumberAnimation {
            target: backdropScrim
            property: "opacity"
            from: 0
            to: 0.25
            duration: 120
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "opacity"
            from: 0
            to: 1
            duration: 120
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 0.96
            to: 1
            duration: 180
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
    }

    Shared.Panel {
        id: panel
        width: Math.min(760, Math.max(280, root.width - Metrics.spacingLarge * 4))
        height: 152
        anchors.centerIn: parent
        customColor: Theme.surface
        padding: Metrics.spacingLarge
        clipContent: true
        transformOrigin: Item.Center
        opacity: Motion.reduced ? 1 : 0
        scale: Motion.reduced ? 1 : 0.96

        ListView {
            id: windowList
            anchors.fill: parent
            model: WindowSwitcherService.windows
            orientation: ListView.Horizontal
            spacing: Metrics.spacingMedium
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Motion.fast
            currentIndex: {
                const windows = WindowSwitcherService.windows;
                for (let index = 0; index < windows.length; index++) {
                    if (windows[index]?.id === WindowSwitcherService.selectedId)
                        return index;
                }
                return -1;
            }

            delegate: WindowSwitcherTile {
                required property var modelData
                window: modelData
            }
        }
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            WindowSwitcherService.accept();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            WindowSwitcherService.previous();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
            WindowSwitcherService.next();
            event.accepted = true;
        }
    }

    Component.onCompleted: root.forceActiveFocus(Qt.PopupFocusReason)
}
