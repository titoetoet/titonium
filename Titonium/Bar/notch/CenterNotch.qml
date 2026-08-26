pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

FocusScope {
    id: root
    focus: true

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.width: Metrics.borderWidth
        border.color: Theme.border
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 20
        bottomRightRadius: 20
    }

    Column {
        anchors.centerIn: parent
        spacing: Metrics.spacingSmall

        Shared.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "deployed_code"
            size: 36
            tone: "accent"
        }
        Shared.TextLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Titonium"
            variant: "title"
            strong: true
        }
    }
}
