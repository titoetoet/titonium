pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.right
import qs.Titonium.Bar.widgets
import qs.Titonium.Theme

Item {
    id: root
    required property var screen
    signal notificationsRequested(var screen, var invoker)
    property bool showConnectivityDiagnostics: true
    property real menuAnchorOffset: 0
    readonly property int preferredWidth: endRow.implicitWidth
        + Metrics.spacingXSmall * 2
    readonly property real menuAnchorX: endRow.x + status.x + status.menuAnchorX
    readonly property real menuAnchorWidth: status.menuAnchorWidth

    implicitWidth: endRow.implicitWidth + Metrics.spacingXSmall * 2
    implicitHeight: Metrics.widgetHeight

    function connectivityAnchorRect(name: string): rect {
        const childRect = connectivity.anchorRect(name);
        if (childRect.width <= 0 || childRect.height <= 0)
            return Qt.rect(0, 0, 0, 0);
        const point = connectivity.mapToItem(root, childRect.x, childRect.y);
        return Qt.rect(point.x, point.y, childRect.width, childRect.height);
    }

    onImplicitWidthChanged: RightPillCoordinator.setCompactWidth("right", root.implicitWidth + 16)
    Component.onCompleted: RightPillCoordinator.setCompactWidth("right", root.implicitWidth + 16)

    Row {
        id: endRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Metrics.spacingXSmall
        spacing: Metrics.spacingSmall

        StatusPill {
            id: status
            screen: root.screen
            menuAnchorOffset: root.menuAnchorOffset
        }

        TopbarPin {
            id: topbarPin
        }

        ConnectivityPill {
            id: connectivity
            screen: root.screen
            showDiagnostics: root.showConnectivityDiagnostics
        }

        NotificationBell {
            screen: root.screen
            onToggleRequested: (screen, invoker) =>
                root.notificationsRequested(screen, invoker)
        }
    }
}
