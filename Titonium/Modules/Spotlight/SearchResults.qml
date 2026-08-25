pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root

    property var spotlightModel: null
    signal activatedSuccessfully()

    function activate(index: int): void {
        root.spotlightModel.selectResult(index);
        if (root.spotlightModel.activateSelected())
            root.activatedSuccessfully();
    }

    ListView {
        id: resultList
        anchors.fill: parent
        model: root.spotlightModel?.results || []
        currentIndex: root.spotlightModel?.selectedIndex || 0
        clip: true
        spacing: Metrics.spacingXSmall
        boundsBehavior: Flickable.StopAtBounds

        delegate: FocusScope {
            id: resultRow
            required property int index
            required property var modelData
            width: resultList.width
            height: 56
            activeFocusOnTab: true

            Rectangle {
                anchors.fill: parent
                radius: Metrics.radiusMedium
                color: resultRow.index === (root.spotlightModel?.selectedIndex || 0)
                    || resultRow.activeFocus || hoverHandler.hovered
                    ? Theme.surfaceInteractive : "transparent"
                border.width: resultRow.activeFocus ? Metrics.borderWidth : 0
                border.color: Theme.focus
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Metrics.spacingMedium
                anchors.rightMargin: Metrics.spacingMedium
                spacing: Metrics.spacingMedium

                Controls.Icon {
                    name: resultRow.modelData.icon || (resultRow.modelData.type === "calculator" ? "calculate" : "apps")
                    size: 24
                    tone: resultRow.modelData.type === "calculator" ? "accent" : "primary"
                    accessibleName: ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Controls.TextLabel {
                        Layout.fillWidth: true
                        text: resultRow.modelData.title
                        variant: "label"
                        strong: resultRow.index === (root.spotlightModel?.selectedIndex || 0)
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                    }
                    Controls.TextLabel {
                        Layout.fillWidth: true
                        text: resultRow.modelData.subtitle
                        variant: "caption"
                        tone: "secondary"
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                    }
                }
            }

            HoverHandler { id: hoverHandler; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.activate(resultRow.index) }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.activate(resultRow.index);
                    event.accepted = true;
                }
            }

            Accessible.role: Accessible.ListItem
            Accessible.name: I18n.tr("spotlight.result_accessible", {
                "title": resultRow.modelData.title,
                "subtitle": resultRow.modelData.subtitle
            })
            Accessible.focusable: true
            Accessible.selected: resultRow.index === (root.spotlightModel?.selectedIndex || 0)
        }

        Controls.TextLabel {
            anchors.centerIn: parent
            visible: resultList.count === 0
            text: I18n.tr("spotlight.no_results")
            tone: "secondary"
        }
    }
}
