pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme

Item {
    id: root

    width: Metrics.widgetHeight
    height: Metrics.widgetHeight
    readonly property bool hovered: logoHover.hovered

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
        id: logoImage
        anchors.centerIn: parent
        width: 24
        height: 24
        source: Qt.resolvedUrl("../assets/arch-prism.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        sourceSize.width: 64
        sourceSize.height: 64
        scale: Motion.reduced ? 1 : (logoHover.hovered ? 1.08 : 1)
        transform: Translate { y: !Motion.reduced && logoHover.hovered ? -1 : 0 }

        Behavior on scale {
            NumberAnimation {
                duration: Motion.reduced ? 0 : 140
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.springDamped
            }
        }
    }

    HoverHandler {
        id: logoHover
        cursorShape: Qt.ArrowCursor
    }

}
