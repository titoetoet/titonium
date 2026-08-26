pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

ColumnLayout {
    id: root

    property string query: ""
    readonly property var filteredApplications: {
        const needle = root.query.trim().toLowerCase();
        if (needle.length === 0)
            return ApplicationVisibilityStore.allApplications;
        return ApplicationVisibilityStore.allApplications.filter(app =>
            String(app?.name || "").toLowerCase().indexOf(needle) >= 0);
    }

    spacing: Metrics.spacingSmall

    QtControls.TextField {
        Layout.fillWidth: true
        implicitHeight: 40
        placeholderText: I18n.tr("settings.spotlight.applications.search")
        text: root.query
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
            border.color: parent.activeFocus ? Theme.focus : Theme.border
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: applicationList
            anchors.fill: parent
            model: root.filteredApplications
            clip: true
            spacing: Metrics.spacingXSmall
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true

            delegate: Controls.Surface {
                id: applicationRow
                required property var modelData
                width: applicationList.width
                implicitHeight: 52
                tone: "elevated"
                outlined: true

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Metrics.spacingMedium
                    anchors.rightMargin: Metrics.spacingMedium
                    spacing: Metrics.spacingMedium

                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source: applicationRow.modelData.icon || ""
                            sourceSize.width: 36
                            sourceSize.height: 36
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }

                        Controls.Icon {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready
                            name: "apps"
                            size: 24
                            tone: "secondary"
                            accessibleName: ""
                        }
                    }

                    Controls.TextLabel {
                        Layout.fillWidth: true
                        text: applicationRow.modelData.name
                        variant: "label"
                        strong: true
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                    }

                    Controls.Switch {
                        checked: ApplicationVisibilityStore.isVisible(applicationRow.modelData.id)
                        accessibleName: I18n.tr(checked
                            ? "settings.spotlight.applications.visible"
                            : "settings.spotlight.applications.hidden", {
                                "name": applicationRow.modelData.name
                            })
                        onToggled: checked => ApplicationVisibilityStore.setVisible(
                            applicationRow.modelData.id, checked)
                    }
                }
            }
        }

        Controls.TextLabel {
            anchors.centerIn: parent
            visible: applicationList.count === 0
            text: I18n.tr("settings.spotlight.applications.empty")
            variant: "body"
            tone: "secondary"
        }
    }
}
