pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme

Item {
    id: root
    property string tone: "surface"
    property int radius: Metrics.radiusSmall
    property int padding: 0
    property bool outlined: true
    property color borderColor: Theme.border
    property bool clipContent: false
    property color customColor: "transparent"
    default property alias contentData: contentItem.data
    readonly property alias contentItem: contentItem
    readonly property color resolvedColor: root.customColor.a > 0 ? root.customColor
        : ({ background: Theme.background, surface: Theme.surface,
            elevated: Theme.surfaceElevated, interactive: Theme.surfaceInteractive })[root.tone]
            || Theme.surface

    implicitWidth: contentItem.childrenRect.width + root.padding * 2
    implicitHeight: contentItem.childrenRect.height + root.padding * 2

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.resolvedColor
        opacity: 1.0
        border.width: root.outlined ? Metrics.borderWidth : 0
        border.color: root.borderColor
    }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: root.padding
        clip: root.clipContent
    }
}
