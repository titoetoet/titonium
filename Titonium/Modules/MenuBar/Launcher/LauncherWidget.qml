pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Composition
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

WidgetBase {
    id: root

    readonly property string surfaceOwnerId: "launcher:" + root.screen.name

    implicitWidth: trigger.implicitWidth
    implicitHeight: Metrics.widgetHeight

    Controls.Button {
        id: trigger
        anchors.fill: parent
        iconName: "apps"
        variant: "quiet"
        size: "small"
        selected: SurfaceCoordinator.ownerId === root.surfaceOwnerId
        accessibleName: I18n.tr("launcher.open")
        onTriggered: {
            if (SurfaceCoordinator.ownerId === root.surfaceOwnerId) {
                SurfaceCoordinator.close(root.surfaceOwnerId);
                return;
            }
            root.context.openSurface(root.surfaceOwnerId, {
                "source": Qt.resolvedUrl("Dashboard.qml"),
                "keyboardFocus": "exclusive",
                "closeOnMonitorChange": true,
                "ownerId": root.surfaceOwnerId
            });
        }
    }
}
