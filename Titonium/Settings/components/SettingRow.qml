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
                wrapMode: Text.WordWrap
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
            // Child positions depend on this slot: measure intrinsic width only.
            Layout.preferredWidth: Math.max(180, ...Array.from(children).map(child => child.implicitWidth || child.width))
            Layout.fillHeight: true
        }
    }
}
