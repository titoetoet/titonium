pragma ComponentBehavior: Bound
// Protected Spotlight vertical slice.

import QtQuick
import qs.Titonium.Theme
import qs.Titonium.Core.Runtime
import "SpotlightLayout.js" as SpotlightLayout

FocusScope {
    id: root

    required property int pageIndex
    required property var page
    required property bool current
    signal triggered()

    readonly property int visualWidth: SpotlightLayout.indicatorVisualWidth(
        root.page, SpotlightLayout.pageSize())
    readonly property real hitMargin: Math.max(0,
        (SpotlightLayout.indicatorTargetWidth() - root.visualWidth) / 2)

    width: root.visualWidth
    height: 20
    activeFocusOnTab: true

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: root.visualWidth
        height: 8
        radius: height / 2
        color: root.current ? Theme.accent : Theme.borderStrong
        border.width: root.activeFocus ? Metrics.borderWidth : 0
        border.color: Theme.focus
    }

    HoverHandler { margin: root.hitMargin; cursorShape: Qt.PointingHandCursor }
    TapHandler { margin: root.hitMargin; onTapped: root.triggered() }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.triggered();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr("spotlight.page_density", {
        "page": root.pageIndex + 1,
        "count": root.page.length,
        "capacity": SpotlightLayout.pageSize()
    })
    Accessible.focusable: true
    Accessible.selected: root.current
}
