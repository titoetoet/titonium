pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root
    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""
    anchors.fill: parent
    focus: true

    function cancelAndClose(): void { ConfigStore.cancel(); SurfaceCoordinator.close(root.ownerId); }
    function applyAndClose(): void { if (ConfigStore.apply()) SurfaceCoordinator.close(root.ownerId); }
    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.42)
        TapHandler { onTapped: eventPoint => { if (!root.pointInside(panel, eventPoint.position)) root.cancelAndClose(); } }
    }
    Controls.Panel {
        id: panel
        z: 1
        width: Math.min(980, root.width - Metrics.spacingLarge * 4)
        height: Math.min(700, root.height - Metrics.spacingLarge * 4)
        anchors.centerIn: parent
        padding: 0
        customColor: Theme.background
        SettingsWorkspace {
            anchors.fill: parent
            currentPage: root.descriptor?.page || "theme"
            onApplyRequested: root.applyAndClose()
            onCancelRequested: root.cancelAndClose()
        }
    }
    Keys.onEscapePressed: event => { root.cancelAndClose(); event.accepted = true; }
    Component.onCompleted: root.forceActiveFocus(Qt.PopupFocusReason)
}
