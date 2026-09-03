pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.SystemTray
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property var invoker: root.descriptor?.invoker || null
    readonly property var popupEntries: SystemTrayService.popupEntries
    readonly property int maximumHeight: 560
    readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing
    readonly property real availableHeight: Math.max(0, root.height - root.panelTop - Metrics.barPadding)
    readonly property real contentHeight: menuView.implicitContentHeight + 2 * panel.padding

    anchors.fill: parent
    focus: true

    property bool closing: false
    property bool focusReturned: false
    property bool navigationReset: false

    function returnFocus(): void {
        if (root.focusReturned)
            return;
        root.focusReturned = true;
        if (root.invoker?.forceActiveFocus)
            root.invoker.forceActiveFocus(Qt.PopupFocusReason);
    }

    function resetNavigation(): void {
        if (root.navigationReset)
            return;
        root.navigationReset = true;
        SystemTrayService.resetPopupNavigation();
    }

    function finishClose(): void {
        root.returnFocus();
        root.resetNavigation();
        if (root.ownerId)
            SurfaceManager.close(root.ownerId);
    }

    function close(): void {
        if (root.closing)
            return;
        root.closing = true;
        if (Motion.reduced) {
            root.finishClose();
            return;
        }
        panelExit.restart();
    }

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(panel, eventPoint.position))
                    root.close();
            }
        }
    }

    Shared.Panel {
        id: panel
        width: 380
        height: Math.min(root.maximumHeight, root.availableHeight, root.contentHeight)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.panelTop
        anchors.rightMargin: Metrics.barPadding
        customColor: Theme.surface
        clipContent: true
        transformOrigin: Item.Top
        opacity: Motion.reduced ? 1 : 0
        scale: Motion.reduced ? 1 : 0.94
        transform: Translate {
            id: panelEntranceOffset
            y: Motion.reduced ? 0 : -12
        }

        SystemTrayMenuView {
            id: menuView
            anchors.fill: parent
            onDismissRequested: root.close()
        }
    }

    ParallelAnimation {
        id: panelEntrance
        running: !Motion.reduced

        NumberAnimation {
            target: panel
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 0.94
            to: 1
            duration: 220
            easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
        }
        NumberAnimation {
            target: panelEntranceOffset
            property: "y"
            from: -12
            to: 0
            duration: 220
            easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1]
        }
    }

    ParallelAnimation {
        id: panelExit

        NumberAnimation {
            target: panel
            property: "opacity"
            from: 1
            to: 0
            duration: 120
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 1
            to: 0.96
            duration: 130
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panelEntranceOffset
            property: "y"
            from: 0
            to: -8
            duration: 130
            easing.type: Easing.InCubic
        }
        onFinished: root.finishClose()
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: panel.forceActiveFocus(Qt.PopupFocusReason)
    Component.onDestruction: root.resetNavigation()
}
