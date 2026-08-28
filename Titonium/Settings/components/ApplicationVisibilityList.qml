pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Applications
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

ColumnLayout {
    id: root

    property string query: ""
    readonly property var filteredApplications: {
        const needle = root.query.trim().toLocaleLowerCase();
        if (needle.length === 0)
            return ApplicationService.allApplications;
        return ApplicationService.allApplications.filter(application =>
            String(application?.name || "").toLocaleLowerCase().indexOf(needle) >= 0
            || String(application?.id || "").toLocaleLowerCase().indexOf(needle) >= 0);
    }

    spacing: Metrics.spacingSmall

    QtControls.TextField {
        id: searchField
        Layout.fillWidth: true
        implicitHeight: 40
        placeholderText: I18n.tr("settings.spotlight.applications.search")
        color: Theme.textPrimary
        placeholderTextColor: Theme.textSecondary
        font.family: Typography.family
        font.pixelSize: Typography.bodySize
        selectByMouse: true
        onTextEdited: root.query = text

        background: Rectangle {
            radius: Metrics.radiusMedium
            color: Theme.surfaceElevated
            border.width: Metrics.borderWidth
            border.color: searchField.activeFocus ? Theme.focus : Theme.border
        }

        Accessible.name: placeholderText
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: applicationList
            anchors.fill: parent
            model: root.filteredApplications
            currentIndex: -1
            clip: true
            spacing: Metrics.spacingXSmall
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true

            delegate: Shared.Surface {
                id: applicationRow
                required property var modelData

                width: applicationList.width
                implicitHeight: 52
                tone: "elevated"
                radius: Metrics.radiusMedium

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Metrics.spacingMedium
                    anchors.rightMargin: Metrics.spacingMedium
                    spacing: Metrics.spacingMedium

                    Shared.SystemIcon {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        sourceName: applicationRow.modelData.icon || ""
                        fallbackName: "apps"
                        size: 32
                    }

                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: applicationRow.modelData.name
                        variant: "label"
                        strong: true
                        elide: Text.ElideRight
                    }

                    Shared.Toggle {
                        checked: Preferences.hiddenApplicationIds.indexOf(
                            applicationRow.modelData.id) < 0
                        accessibleName: I18n.tr(checked
                            ? "settings.spotlight.applications.visible"
                            : "settings.spotlight.applications.hidden", {
                                "name": applicationRow.modelData.name
                            })
                        onToggled: checked => Preferences.patch("applications.hiddenIds",
                            ApplicationService.hiddenIdsForVisibility(
                                Preferences.hiddenApplicationIds,
                                applicationRow.modelData.id, checked))
                    }
                }
            }
        }

        Shared.TextLabel {
            anchors.centerIn: parent
            visible: applicationList.count === 0
            text: I18n.tr("settings.spotlight.applications.empty")
            tone: "secondary"
        }
    }
}
