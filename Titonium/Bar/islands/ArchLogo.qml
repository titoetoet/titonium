pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    width: Metrics.widgetHeight
    height: Metrics.widgetHeight
    readonly property bool hovered: logoHover.hovered
    scale: root.hovered ? 1.04 : 1.0

    Shared.Surface {
        anchors.fill: parent
        tone: root.hovered ? "interactive" : "elevated"
        radius: Metrics.radiusLarge
        outlined: false
    }

    Rectangle {
        anchors.centerIn: parent
        width: 27
        height: 27
        radius: 9
        color: root.hovered
            ? Qt.rgba(0.36, 0.61, 1.0, 0.18)
            : Qt.rgba(0.36, 0.61, 1.0, 0.09)
    }

    Image {
        anchors.centerIn: parent
        width: 24
        height: 24
        source: Qt.resolvedUrl("../assets/arch-prism.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        sourceSize.width: 64
        sourceSize.height: 64
    }

    HoverHandler {
        id: logoHover
        cursorShape: Qt.ArrowCursor
    }

    Behavior on scale {
        NumberAnimation {
            duration: Motion.fast
            easing.type: Easing.OutCubic
        }
    }
}
