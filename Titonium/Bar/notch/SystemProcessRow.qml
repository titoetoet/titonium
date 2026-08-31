pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Shared.Surface {
    id: root

    required property var process
    required property string memoryText
    property int rank: 0

    Layout.minimumHeight: 36
    Layout.preferredHeight: 36
    tone: "interactive"
    radius: Metrics.radiusSmall
    padding: Metrics.spacingSmall
    Accessible.name: root.process.name
    Accessible.description: Math.round(root.process.cpuPercent) + "% · " + root.memoryText

    RowLayout {
        anchors.fill: parent
        spacing: Metrics.spacingSmall

        Shared.TextLabel {
            Layout.preferredWidth: 18
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
            tone: root.process.cpuPercent >= 70 ? "warning" : "accent"
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
    }
}
