pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Dock
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property var item: root.descriptor?.item || null
    readonly property string appId: root.item?.appId || ""
    readonly property var invoker: root.descriptor?.invoker || null

    anchors.fill: parent
    focus: true

    property bool closing: false

    function returnFocus(): void {
        if (root.invoker && root.invoker.forceActiveFocus)
            root.invoker.forceActiveFocus(Qt.PopupFocusReason);
    }

    function close(): void {
        root.returnFocus();
        if (Motion.reduced) {
            if (root.ownerId)
                SurfaceManager.close(root.ownerId);
            return;
        }
        if (root.closing)
            return;
        root.closing = true;
        menuExit.restart();
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
        width: 220
        height: menuColumn.implicitHeight + menuPanel.padding * 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        customColor: Theme.surface
        transformOrigin: Item.Bottom
        opacity: Motion.reduced ? 1 : 0
        scale: Motion.reduced ? 1 : 0.94
        transform: Translate {
            id: menuTranslate
            y: Motion.reduced ? 0 : 8
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
                from: 0.96
                to: 1
                duration: 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.springDamped
            }
            NumberAnimation {
                target: menuTranslate
                property: "y"
                from: 6
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
                to: 0.96
                duration: 120
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: menuTranslate
                property: "y"
                from: 0
                to: 6
                duration: 120
                easing.type: Easing.InCubic
            }
            onFinished: {
                if (root.ownerId)
                    SurfaceManager.close(root.ownerId);
            }
        }

        ColumnLayout {
            id: menuColumn
            anchors.fill: parent
            spacing: Metrics.spacingSmall

            Shared.Button {
                Layout.fillWidth: true
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

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: menuPanel.forceActiveFocus(Qt.PopupFocusReason)
    Component.onDestruction: root.returnFocus()
}
