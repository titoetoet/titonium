pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import "CenterActionCatalog.js" as CenterActionCatalog

FocusScope {
    id: root
    property string pageId: "session"
    readonly property var actions: CenterActionCatalog.session()
    signal feedbackRequested(string key)

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingLarge

        Shared.TextLabel {
            text: I18n.tr("center_notch.session.title")
            variant: "title"
            strong: true
        }

        GridLayout {
            id: actionGrid
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            columns: actionGrid.width >= 540 ? 3 : 2
            columnSpacing: Metrics.spacingMedium
            rowSpacing: Metrics.spacingMedium

            Repeater {
                model: root.actions
                CenterActionButton {
                    id: actionTile
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    descriptor: actionTile.modelData
                    onActionRequested: (intent, feedbackKey) => root.feedbackRequested(feedbackKey)
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
