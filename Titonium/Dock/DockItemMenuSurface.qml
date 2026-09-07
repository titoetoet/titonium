pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Dock
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "DockMenuGeometry.js" as DockMenuGeometry

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property var item: root.descriptor?.item || null
    readonly property string appId: root.item?.appId || ""
    readonly property var invoker: root.descriptor?.invoker || null

    readonly property bool connected: Preferences.dockStyle === "connected"
    readonly property rect dockBounds: SurfaceInputRegions.regionsFor(root.screen).body
    readonly property real anchorX: {
        // Depend on layout changes as running applications enter and leave the Dock.
        if (!root.invoker || root.invoker.x < 0 || root.dockBounds.width <= 0)
            return root.dockBounds.x + root.dockBounds.width / 2;
        return root.invoker.mapToItem(null, root.invoker.width / 2, 0).x;
    }
    readonly property var menuBounds: DockMenuGeometry.panelRect(root.width, root.height,
        root.dockBounds, root.anchorX, 320,
        menuColumn.implicitHeight + menuPanel.padding * 2, root.connected)
    readonly property color menuColor: root.connected
        ? (Theme.connectedSurface) : Theme.surface

    anchors.fill: parent
    focus: true

    property bool closing: false
    property bool focusReturned: false
    property var closingDescriptor: null
    property var closingScreen: null

    function returnFocus(): void {
        if (root.focusReturned || (SurfaceManager.active && !SurfaceManager.matches(
                root.ownerId, root.closingDescriptor || root.descriptor,
                root.closingScreen || root.screen)))
            return;
        root.focusReturned = true;
        if (root.invoker?.forceActiveFocus)
            root.invoker.forceActiveFocus(Qt.PopupFocusReason);
    }

    function finishClose(): void {
        if (!SurfaceManager.matches(root.ownerId, root.closingDescriptor, root.closingScreen))
            return;
        root.returnFocus();
        SurfaceManager.closeOwned(root.ownerId, root.closingDescriptor, root.closingScreen);
    }

    function close(): void {
        if (root.closing || !SurfaceManager.beginClose(root.ownerId, root.descriptor, root.screen))
            return;
        root.closingDescriptor = root.descriptor;
        root.closingScreen = root.screen;
        root.closing = true;
        menuEntrance.stop();
        if (Motion.reduced)
            root.finishClose();
        else
            menuExit.restart();
    }

    onDescriptorChanged: {
        if (root.closing && root.descriptor !== root.closingDescriptor) {
            menuExit.stop();
            root.closing = false;
            root.focusReturned = false;
            root.closingDescriptor = null;
            root.closingScreen = null;
            if (!Motion.reduced)
                menuEntrance.restart();
        }
    }

    Connections {
        target: Preferences
        function onDockStyleChanged(): void {
            SurfaceManager.closeOwned(root.ownerId, root.descriptor, root.screen);
        }
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
                if (!root.pointInside(menuPanel, eventPoint.position))
                    root.close();
            }
        }
    }

    Shared.Panel {
        id: menuPanel
        x: root.menuBounds.x
        y: root.menuBounds.y
        width: root.menuBounds.width
        height: root.menuBounds.height
        customColor: root.menuColor
        outlined: !root.connected
        radius: root.connected ? 20 : Metrics.radiusLarge
        transformOrigin: Item.Bottom
        opacity: Motion.reduced ? 1 : 0
        scale: Motion.reduced || root.connected ? 1 : 0.94
        transform: Translate {
            id: menuTranslate
            y: Motion.reduced || root.connected ? 0 : 8
        }

        ParallelAnimation {
            id: menuEntrance
            running: !Motion.reduced

            NumberAnimation {
                target: menuPanel
                property: "opacity"
                from: 0
                to: 1
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: menuPanel
                property: "scale"
                from: root.connected ? 1 : 0.94
                to: 1
                duration: 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.springDamped
            }
            NumberAnimation {
                target: menuTranslate
                property: "y"
                from: root.connected ? 0 : 8
                to: 0
                duration: 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.springDamped
            }
        }

        ParallelAnimation {
            id: menuExit

            NumberAnimation {
                target: menuPanel
                property: "opacity"
                from: 1
                to: 0
                duration: 110
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: menuPanel
                property: "scale"
                from: 1
                to: root.connected ? 1 : 0.96
                duration: 120
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: menuTranslate
                property: "y"
                from: 0
                to: root.connected ? 0 : 6
                duration: 120
                easing.type: Easing.InCubic
            }
            onFinished: root.finishClose()
        }

        Flickable {
            anchors.fill: parent
            contentHeight: menuColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: menuColumn
                width: parent.width
                spacing: Metrics.spacingSmall

                Shared.Button {
                    Layout.fillWidth: true
                    variant: "quiet"
                    label: I18n.tr("dock.menu.new_window")
                    iconName: "add"
                    contentAlignment: Qt.AlignLeft
                    onTriggered: {
                        DockService.launchNew(root.appId);
                        root.close();
                    }
                }

                Shared.Button {
                    Layout.fillWidth: true
                    variant: "quiet"
                    label: I18n.tr(root.item?.pinned ? "dock.menu.unpin" : "dock.menu.pin")
                    iconName: "keep"
                    contentAlignment: Qt.AlignLeft
                    onTriggered: {
                        const result = DockService.togglePin(root.appId);
                        if (result.accepted)
                            root.close();
                        else
                            Logger.warn("dock", "pin mutation rejected: " + result.error);
                    }
                }

                Shared.Button {
                    Layout.fillWidth: true
                    label: I18n.tr("dock.menu.close_active")
                    iconName: "close"
                    variant: "danger"
                    contentAlignment: Qt.AlignLeft
                    visible: root.item?.runningCount > 0
                    enabled: root.item?.runningCount > 0
                    onTriggered: {
                        DockService.closeActive(root.appId);
                        root.close();
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: menuPanel.forceActiveFocus(Qt.PopupFocusReason)
    Component.onDestruction: root.returnFocus()
}
