pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Theme

FocusScope {
    id: root
    focus: true
    clip: true
    property bool entranceRequested: Motion.reduced

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.width: Metrics.borderWidth
        border.color: Theme.border
        topLeftRadius: 20
        topRightRadius: 20
        bottomLeftRadius: 20
        bottomRightRadius: 20
    }

    Item {
        id: contentLayer
        anchors.fill: parent
        opacity: Motion.reduced ? 1 : 0
        transform: Translate {
            id: contentEntranceOffset
            y: Motion.reduced ? 0 : -4
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Metrics.spacingLarge
            spacing: Metrics.spacingMedium

            CenterNotchViewport {
                Layout.fillWidth: true
                Layout.fillHeight: true
                requestedPage: CenterNotchCoordinator.requestedPage
            }
        }
    }

    SequentialAnimation {
        running: root.entranceRequested && !Motion.reduced
        ParallelAnimation {
            NumberAnimation {
                target: contentLayer
                property: "opacity"
                from: 0
                to: 1
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: contentEntranceOffset
                property: "y"
                from: -4
                to: 0
                duration: 170
                easing.type: Easing.OutCubic
            }
        }
    }
}
