pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.notch
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root
    required property var screen

    implicitWidth: 180
    implicitHeight: Metrics.controlHeight

    Shared.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusLarge
    }

    Shared.Button {
        anchors.fill: parent
        label: "Titonium"
        iconName: "deployed_code"
        variant: "quiet"
        size: "medium"
        backgroundRadius: Metrics.radiusLarge
        accessibleName: I18n.tr("menubar.center_notch.accessible")
        opacity: CenterNotchCoordinator.ownerScreenName === root.screen.name ? 0 : 1
        onTriggered: CenterNotchCoordinator.toggle(root.screen.name)
    }
}
