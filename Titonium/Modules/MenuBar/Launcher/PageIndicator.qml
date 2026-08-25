pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Foundation

FocusScope {
    id: root

    required property int pageIndex
    required property real fillRatio
    required property bool current
    signal triggered()

    width: root.current ? 12 + Math.round(28 * root.fillRatio) : 8
    height: 20
    activeFocusOnTab: true

    Behavior on width {
        NumberAnimation {
            duration: ConfigStore.previewState.accessibility?.reducedMotion === true ? 0 : Motion.fast
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: 8
        radius: height / 2
        color: root.current ? Theme.accent : Theme.borderStrong
        border.width: root.activeFocus ? Metrics.borderWidth : 0
        border.color: Theme.focus
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
    Accessible.name: I18n.tr("launcher.page_go", { "page": root.pageIndex + 1 })
    Accessible.focusable: true
}
