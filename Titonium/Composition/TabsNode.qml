pragma ComponentBehavior: Bound

import QtQuick
import Titonium.Design

Item {
    id: root

    required property var node
    required property var screen
    required property var context
    property int currentIndex: 0

    readonly property var tabs: root.node.pages || []
    readonly property var activeTab: root.tabs[root.currentIndex] || ({})

    implicitWidth: Math.max(tabRow.implicitWidth, page.implicitWidth)
    implicitHeight: tabRow.implicitHeight + Metrics.spacingXSmall + page.implicitHeight

    Row {
        id: tabRow
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Metrics.spacingXSmall

        Repeater {
            model: root.tabs

            Rectangle {
                id: tabButton
                required property var modelData
                required property int index
                implicitWidth: label.implicitWidth + Metrics.spacingSmall * 2
                implicitHeight: Metrics.controlHeightSmall
                radius: Metrics.radiusSmall
                color: index === root.currentIndex ? Theme.surfaceElevated : "transparent"

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: tabButton.modelData.label || tabButton.modelData.id
                    color: Theme.textPrimary
                    font.family: Typography.family
                    font.pixelSize: Typography.labelSize
                }

                TapHandler { onTapped: root.currentIndex = tabButton.index }
            }
        }
    }

    NodeHost {
        id: page
        anchors.top: tabRow.bottom
        anchors.topMargin: Metrics.spacingXSmall
        anchors.horizontalCenter: parent.horizontalCenter
        node: root.activeTab.child || {
            "type": "spacer",
            "id": root.node.id + ".empty",
            "size": 0
        }
        screen: root.screen
        context: root.context
    }
}
