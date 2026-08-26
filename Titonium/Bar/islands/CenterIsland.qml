pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.notch
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared

Item {
    id: root
    required property var screen

    implicitWidth: 180
    implicitHeight: 32

    Shared.Button {
        anchors.fill: parent
        label: "Titonium"
        iconName: "deployed_code"
        variant: "secondary"
        size: "medium"
        accessibleName: I18n.tr("menubar.center_notch.accessible")
        opacity: 1
        onTriggered: CenterNotchCoordinator.toggle(root.screen.name)
    }
}
