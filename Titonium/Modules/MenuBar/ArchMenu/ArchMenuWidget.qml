pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Composition
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

WidgetBase {
    id: root

    readonly property string surfaceOwnerId: "arch-menu:" + root.screen.name

    implicitWidth: trigger.implicitWidth
    implicitHeight: Metrics.widgetHeight

    Controls.Button {
        id: trigger
        anchors.fill: parent
        iconName: ""
        variant: "quiet"
        size: "small"
        selected: SurfaceCoordinator.ownerId === root.surfaceOwnerId
        accessibleName: I18n.tr("arch_menu.open")

        onTriggered: {
            if (SurfaceCoordinator.ownerId === root.surfaceOwnerId) {
                SurfaceCoordinator.close(root.surfaceOwnerId);
                return;
            }
            root.context.openSurface(root.surfaceOwnerId, {
                "source": Qt.resolvedUrl("ArchMenu.qml"),
                "keyboardFocus": "exclusive",
                "closeOnMonitorChange": true,
                "ownerId": root.surfaceOwnerId
            });
        }
    }

    Image {
        anchors.centerIn: trigger
        width: 22
        height: 22
        source: Qt.resolvedUrl("../../../../assets/icons/archlinux.svg")
        sourceSize.width: 32
        sourceSize.height: 32
        fillMode: Image.PreserveAspectFit
    }
}
