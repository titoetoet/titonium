pragma ComponentBehavior: Bound
// Protected Spotlight vertical slice.

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Theme
import qs.Titonium.Shared as Controls
import qs.Titonium.Core.Runtime

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

                Item {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24

                    Image {
                        id: resultApplicationIcon
                        anchors.fill: parent
                        visible: resultRow.modelData.type === "application"
                        source: resultRow.modelData.type === "application" ? (resultRow.modelData.icon || "") : ""
                        sourceSize.width: 32
                        sourceSize.height: 32
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                    }

                    Controls.Icon {
                        anchors.centerIn: parent
                        visible: resultRow.modelData.type !== "application"
                            || resultApplicationIcon.status !== Image.Ready
                        name: resultRow.modelData.type === "calculator" ? "calculate" : "apps"
                        size: 24
                        tone: resultRow.modelData.type === "calculator" ? "accent" : "secondary"
                        accessibleName: ""
                    }
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
                if (event.key === Qt.Key_Down) {
                    root.spotlightModel.moveSelection(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    root.spotlightModel.moveSelection(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    if (root.spotlightModel.activateSelected())
                        root.activatedSuccessfully();
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
