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

    function returnFocus(): void {
        if (root.invoker && root.invoker.forceActiveFocus)
            root.invoker.forceActiveFocus(Qt.PopupFocusReason);
    }

    function close(): void {
        root.returnFocus();
        if (root.ownerId)
            SurfaceManager.close(root.ownerId);
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
                    DockService.togglePin(root.appId);
                    root.close();
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
