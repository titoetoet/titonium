pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Composition
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

WidgetBase {
    id: root

    readonly property string surfaceOwnerId: "calendar:" + root.screen.name
    readonly property bool use24Hour: root.node.props?.use24Hour !== false

    implicitWidth: trigger.implicitWidth
    implicitHeight: Metrics.widgetHeight

    Controls.Button {
        id: trigger
        anchors.fill: parent
        label: ClockModel.timeText(root.use24Hour)
        iconName: "schedule"
        variant: "quiet"
        size: "small"
        selected: SurfaceCoordinator.ownerId === root.surfaceOwnerId
        accessibleName: I18n.tr("menubar.clock.accessible")
        onTriggered: {
            if (SurfaceCoordinator.ownerId === root.surfaceOwnerId) {
                SurfaceCoordinator.close(root.surfaceOwnerId);
                return;
            }
            root.context.openSurface(root.surfaceOwnerId, {
                "source": Qt.resolvedUrl("CalendarPanel.qml"),
                "keyboardFocus": "exclusive",
                "ownerId": root.surfaceOwnerId
            });
        }
    }
}
