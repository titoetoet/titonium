pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var process
    required property string memoryText

    implicitHeight: 28
    Accessible.name: root.process.name
    Accessible.description: Math.round(root.process.cpuPercent) + "% · " + root.memoryText

    RowLayout {
        anchors.fill: parent
        spacing: Metrics.spacingMedium

        Shared.TextLabel {
            Layout.fillWidth: true
            text: root.process.name
            variant: "caption"
            elide: Text.ElideRight
        }
        Shared.TextLabel {
            Layout.preferredWidth: 56
            text: Math.round(root.process.cpuPercent) + "%"
            variant: "caption"
            horizontalAlignment: Text.AlignRight
        }
        Shared.TextLabel {
            Layout.preferredWidth: 72
            text: root.memoryText
            variant: "caption"
            tone: "secondary"
            horizontalAlignment: Text.AlignRight
        }
    }
}
