pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.SystemTray
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "../../Bar/right/EdgeMenuGeometry.js" as EdgeMenuGeometry

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property var invoker: root.descriptor?.invoker || null
    readonly property var anchorRect: root.descriptor?.anchorRect || null
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
    property var closingDescriptor: null
    property var closingScreen: null
    property var closingInvoker: null

    function returnFocus(): void {
        if (root.focusReturned)
            return;
        const ownedDescriptor = root.closingDescriptor || root.descriptor;
        const ownedScreen = root.closingScreen || root.screen;
        if (SurfaceManager.active
                && !SurfaceManager.matches(root.ownerId, ownedDescriptor, ownedScreen))
            return;
        root.focusReturned = true;
        const target = root.closingInvoker || root.invoker;
        if (target?.forceActiveFocus)
            target.forceActiveFocus(Qt.PopupFocusReason);
    }

    function resetNavigation(): void {
        if (root.navigationReset)
            return;
        root.navigationReset = true;
        SystemTrayService.resetPopupNavigation();
    }

    function finishClose(): void {
        if (!root.closingDescriptor || !SurfaceManager.matches(
                root.ownerId, root.closingDescriptor, root.closingScreen))
            return;
        root.returnFocus();
        root.resetNavigation();
        SurfaceManager.closeOwned(root.ownerId, root.closingDescriptor, root.closingScreen);
    }

    function reopenIfReplaced(): void {
        if (!root.closing || root.descriptor === root.closingDescriptor)
            return;
        panelExit.stop();
        root.closing = false;
        root.closingDescriptor = null;
        root.closingScreen = null;
        root.closingInvoker = null;
        root.focusReturned = false;
        root.navigationReset = false;
        if (!Motion.reduced)
            panelEntrance.restart();
        panel.forceActiveFocus(Qt.PopupFocusReason);
    }

    function close(): void {
        if (root.closing)
            return;
        if (!SurfaceManager.beginClose(root.ownerId, root.descriptor, root.screen))
            return;
        root.closingDescriptor = root.descriptor;
        root.closingScreen = root.screen;
        root.closingInvoker = root.invoker;
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
        width: Math.min(380, Math.max(1, root.width - Metrics.barPadding * 2))
        height: Math.min(root.maximumHeight, root.availableHeight, root.contentHeight)
        x: EdgeMenuGeometry.detachedPopupX(root.anchorRect, root.descriptor?.anchorScreenName
            || "", root.width, panel.width, Metrics.barPadding)
        anchors.top: parent.top
        anchors.topMargin: root.panelTop
        customColor: Theme.surface
        clipContent: true
        transformOrigin: root.descriptor?.anchorEdge === "left"
            ? Item.TopLeft : Item.TopRight
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

    onDescriptorChanged: root.reopenIfReplaced()
    Component.onCompleted: panel.forceActiveFocus(Qt.PopupFocusReason)
    Component.onDestruction: root.resetNavigation()
}
