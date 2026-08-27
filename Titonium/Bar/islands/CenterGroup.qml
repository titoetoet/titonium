pragma ComponentBehavior: Bound

import QtQuick
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
        spacing: Metrics.spacingSmall

        Item {
            id: pinPill
            width: Metrics.controlHeight
            height: Metrics.controlHeight

            Shared.Surface {
                anchors.fill: parent
                tone: "elevated"
                radius: Metrics.radiusLarge
            }

            Shared.Button {
                anchors.fill: parent
                iconName: BarVisibilityState.pinned ? "keep" : "keep_off"
                variant: "quiet"
                size: "small"
                selected: BarVisibilityState.pinned
                showFocusRing: false
                backgroundRadius: Metrics.radiusLarge
                accessibleName: I18n.tr(BarVisibilityState.pinned
                    ? "menubar.bar_pin.autohide" : "menubar.bar_pin.pin")
                onTriggered: BarVisibilityState.togglePinned()
            }
        }

        CenterIsland {
            screen: root.screen
        }
    }
}
