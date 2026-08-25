pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design

Item {
    id: root

    property string tone: "surface"
    property int radius: Metrics.radiusSmall
    property int padding: 0
    property bool outlined: true
    property color borderColor: Theme.border
    property bool clipContent: false
    property color customColor: "transparent"
    property string materialBackend: ""
    default property alias contentData: contentItem.data
    readonly property alias contentItem: contentItem

    readonly property color resolvedColor: {
        if (root.customColor.a > 0)
            return root.customColor;
        const tones = {
            background: Theme.background,
            surface: Theme.surface,
            elevated: Theme.surfaceElevated,
            interactive: Theme.surfaceInteractive
        };
        return tones[root.tone] || Theme.surface;
    }

    implicitWidth: contentItem.childrenRect.width + root.padding * 2
    implicitHeight: contentItem.childrenRect.height + root.padding * 2

    MaterialSurface {
        anchors.fill: parent
        backend: root.materialBackend
        radius: root.radius
        outlined: root.outlined
        borderColor: root.borderColor
        customColor: root.resolvedColor
    }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: root.padding
        clip: root.clipContent
    }
}
