pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var screen
    implicitWidth: centerRow.implicitWidth + Metrics.spacingXSmall * 2
    implicitHeight: Metrics.controlHeight

    Shared.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusLarge
    }

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
            iconName: BarVisibilityState.pinned ? "keep" : "keep_off"
            variant: "quiet"
            size: "small"
            selected: BarVisibilityState.pinned
            accessibleName: I18n.tr(BarVisibilityState.pinned
                ? "menubar.bar_pin.autohide" : "menubar.bar_pin.pin")
            onTriggered: BarVisibilityState.togglePinned()
        }
    }
}
