pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var process
    required property string memoryText
    property int rank: 0

    Layout.minimumHeight: 44
    Layout.preferredHeight: 44
    Accessible.name: root.process.name
    Accessible.description: Math.round(root.process.cpuPercent) + "% · " + root.memoryText

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusSmall
        color: root.rank % 2 === 0 ? Theme.surfaceInteractive : "transparent"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingSmall
        anchors.rightMargin: Metrics.spacingSmall
        spacing: Metrics.spacingSmall

        Shared.TextLabel {
            Layout.preferredWidth: 20
            text: root.rank > 0 ? String(root.rank) + "." : ""
            variant: "caption"
            tone: "secondary"
            strong: true
        }
        Shared.Icon {
            name: "terminal"
            size: 18
            tone: "accent"
            accessibleName: root.process.name
        }
        Shared.TextLabel {
            Layout.fillWidth: true
            text: root.process.name
            variant: "caption"
            strong: true
            elide: Text.ElideRight
        }
        Shared.TextLabel {
            Layout.preferredWidth: 52
            text: Math.round(root.process.cpuPercent) + "%"
            variant: "caption"
            tone: root.process.cpuPercent >= 70 ? "warning" : "success"
            strong: true
            horizontalAlignment: Text.AlignRight
        }
        Shared.TextLabel {
            Layout.preferredWidth: 72
            text: root.memoryText
            variant: "caption"
            tone: "secondary"
            horizontalAlignment: Text.AlignRight
        }
        Shared.TextLabel {
            Layout.preferredWidth: 56
            text: "Running"
            variant: "caption"
            tone: "success"
            horizontalAlignment: Text.AlignRight
        }
    }
}
