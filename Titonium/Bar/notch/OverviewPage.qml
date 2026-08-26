pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

FocusScope {
    id: root
    property string pageId: "overview"
    signal feedbackRequested(string key)

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingLarge

        Shared.TextLabel {
            text: root.pageId === "overview" ? I18n.tr("center_notch.title")
                : I18n.tr("center_notch.tab." + root.pageId)
            variant: "title"
            strong: true
        }
        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("center_notch.overview.description")
            tone: "secondary"
            wrapMode: Text.WordWrap
        }

        GridLayout {
            id: cardGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: cardGrid.width >= 600 ? 2 : 1
            columnSpacing: Metrics.spacingMedium
            rowSpacing: Metrics.spacingMedium

            Repeater {
                model: [
                    { "icon": "view_quilt", "key": "center_notch.overview.layout" },
                    { "icon": "keyboard", "key": "center_notch.overview.keyboard" },
                    { "icon": "deployed_code_update", "key": "center_notch.overview.lazy" },
                    { "icon": "layers", "key": "center_notch.overview.solid" }
                ]

                Shared.Surface {
                    id: card
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 96
                    tone: "elevated"
                    radius: Metrics.radiusMedium
                    padding: Metrics.spacingLarge

                    Column {
                        anchors.centerIn: parent
                        spacing: Metrics.spacingSmall

                        Shared.Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: card.modelData.icon
                            size: 28
                            tone: "accent"
                        }
                        Shared.TextLabel {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: I18n.tr(card.modelData.key)
                            variant: "label"
                            strong: true
                        }
                    }
                }
            }
        }
    }
}
