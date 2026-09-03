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

    function close(): void {
        if (root.invoker?.forceActiveFocus)
            root.invoker.forceActiveFocus(Qt.PopupFocusReason);
        SystemTrayService.resetPopupNavigation();
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

        SystemTrayMenuView {
            id: menuView
            anchors.fill: parent
            onDismissRequested: root.close()
        }
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: panel.forceActiveFocus(Qt.PopupFocusReason)
}
