pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Foundation
import "SpotlightLayout.js" as SpotlightLayout

FocusScope {
    id: root

    required property int pageIndex
    required property var page
    required property bool current
    signal triggered()

    width: SpotlightLayout.indicatorTrackWidth()
    height: 20
    activeFocusOnTab: true

    Rectangle {
        id: track
        anchors.centerIn: parent
        width: parent.width
        height: 8
        radius: height / 2
        color: Theme.border
        border.width: root.activeFocus ? Metrics.borderWidth : 0
        border.color: Theme.focus

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: SpotlightLayout.indicatorFillWidth(root.page, SpotlightLayout.pageSize())
            height: parent.height
            radius: height / 2
            color: root.current ? Theme.accent : Theme.borderStrong
        }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.triggered() }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.triggered();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr("spotlight.page_go", { "page": root.pageIndex + 1 })
    Accessible.focusable: true
    Accessible.selected: root.current
}
