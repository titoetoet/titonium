pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.notch
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var screen
    implicitWidth: centerRow.implicitWidth
    implicitHeight: Metrics.controlHeight

    Row {
        id: centerRow
        anchors.centerIn: parent
        spacing: Metrics.spacingXSmall

        CenterIsland {
            screen: root.screen
        }

        Shared.Button {
            width: Metrics.controlHeightSmall
            height: Metrics.controlHeightSmall
            iconName: CenterNotchCoordinator.pinned
                && CenterNotchCoordinator.ownerScreenName === root.screen.name
                ? "keep" : "keep_off"
            variant: "quiet"
            size: "small"
            selected: CenterNotchCoordinator.pinned
                && CenterNotchCoordinator.ownerScreenName === root.screen.name
            accessibleName: I18n.tr(selected
                ? "menubar.center_pin.close" : "menubar.center_pin.open")
            onTriggered: CenterNotchCoordinator.togglePinned(root.screen.name)
        }
    }
}
