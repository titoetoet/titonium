pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root

    required property var sections
    required property string selectedSection
    signal sectionSelected(string sectionId)

    implicitWidth: 68

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingSmall
        spacing: Metrics.spacingSmall

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 44
            implicitHeight: 44
            radius: width / 2
            color: Theme.surfaceElevated
            border.width: Metrics.borderWidth
            border.color: Theme.borderStrong

            Controls.Icon {
                anchors.centerIn: parent
                name: ConfigStore.previewState.modules?.launcher?.avatarIcon || "terminal"
                size: 26
                tone: "accent"
                accessibleName: ""
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: Metrics.borderWidth; color: Theme.border }

        Repeater {
            model: root.sections.filter(section => section.placement !== "bottom")

            Controls.Button {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 48
                iconName: modelData.icon
                variant: "quiet"
                selected: root.selectedSection === modelData.id
                accessibleName: I18n.tr(modelData.labelKey)
                onTriggered: root.sectionSelected(modelData.id)
            }
        }

        Item { Layout.fillHeight: true }

        Repeater {
            model: root.sections.filter(section => section.placement === "bottom")

            Controls.Button {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 48
                iconName: modelData.icon
                variant: modelData.id === "power" ? "danger" : "quiet"
                selected: root.selectedSection === modelData.id
                accessibleName: I18n.tr(modelData.labelKey)
                onTriggered: root.sectionSelected(modelData.id)
            }
        }
    }
}
