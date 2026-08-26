pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root

    property var spotlightModel: null

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(440, parent.width)
        spacing: Metrics.spacingMedium

        Controls.Icon {
            Layout.alignment: Qt.AlignHCenter
            name: "manage_search"
            size: 48
            tone: "accent"
        }

        Text {
            Layout.fillWidth: true
            text: I18n.tr("spotlight.system.title")
            color: Theme.textPrimary
            font.family: Typography.family
            font.pixelSize: Typography.titleSize
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            text: root.spotlightModel?.query?.trim().length > 0
                ? I18n.tr("spotlight.system.mock_query", { "query": root.spotlightModel.query })
                : I18n.tr("spotlight.system.mock_hint")
            color: Theme.textSecondary
            font.family: Typography.family
            font.pixelSize: Typography.bodySize
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
