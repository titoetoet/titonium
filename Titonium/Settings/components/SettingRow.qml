pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root

    property string title: ""
    property string description: ""
    default property alias content: controlSlot.data

    implicitHeight: Math.max(64, labels.implicitHeight + Metrics.spacingMedium * 2)

    RowLayout {
        anchors.fill: parent
        spacing: Metrics.spacingLarge

        ColumnLayout {
            id: labels
            Layout.fillWidth: true
            spacing: Metrics.spacingXSmall

            Shared.TextLabel {
                Layout.fillWidth: true
                text: root.title
                variant: "label"
                strong: true
                elide: Text.ElideRight
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                visible: root.description.length > 0
                text: root.description
                variant: "bodySmall"
                tone: "secondary"
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: controlSlot
            Layout.preferredWidth: Math.max(180, childrenRect.width)
            Layout.fillHeight: true
        }
    }
}
