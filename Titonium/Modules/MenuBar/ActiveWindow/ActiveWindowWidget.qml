pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Composition
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

WidgetBase {
    id: root

    readonly property int maximumWidth: Math.max(160, Number(root.node.props?.maximumWidth || 560))
    readonly property int activeMaximumWidth: Math.max(120,
        Number(root.node.props?.activeMaximumWidth || 240))
    readonly property int compactWidth: Metrics.controlHeightSmall

    implicitWidth: Math.min(root.maximumWidth, taskList.contentWidth)
    implicitHeight: Metrics.widgetHeight
    visible: windowModel.items.length > 0

    ActiveWindowModel { id: windowModel }

    ListView {
        id: taskList

        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: Metrics.spacingXSmall
        model: windowModel.items
        interactive: contentWidth > width
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        delegate: FocusScope {
            id: taskItem

            required property var modelData
            readonly property bool activeWindow: modelData.active === true
            readonly property int expandedWidth: Math.min(root.activeMaximumWidth,
                Math.max(96, taskContent.implicitWidth + Metrics.spacingMedium * 2))
            readonly property bool hovered: taskHover.hovered

            width: activeWindow ? expandedWidth : root.compactWidth
            height: Metrics.widgetHeight
            activeFocusOnTab: true

            Behavior on width {
                NumberAnimation { duration: Motion.normal; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                radius: Metrics.radiusSmall
                color: taskItem.activeWindow || taskItem.hovered
                    ? Theme.surfaceInteractive : "transparent"
                border.width: taskItem.activeWindow || taskItem.activeFocus ? Metrics.borderWidth : 0
                border.color: taskItem.activeFocus ? Theme.focus : Theme.borderStrong

                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }

            Row {
                id: taskContent

                anchors.centerIn: parent
                spacing: taskItem.activeWindow ? Metrics.spacingSmall : 0

                Item {
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: appIcon
                        anchors.fill: parent
                        source: taskItem.modelData.icon || ""
                        sourceSize.width: 40
                        sourceSize.height: 40
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                    }

                    Controls.Icon {
                        anchors.centerIn: parent
                        visible: appIcon.status !== Image.Ready
                        name: "apps"
                        size: 18
                        tone: taskItem.activeWindow ? "accent" : "secondary"
                        accessibleName: ""
                    }
                }

                Controls.TextLabel {
                    visible: taskItem.activeWindow
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? Math.min(implicitWidth,
                        root.activeMaximumWidth - 20 - Metrics.spacingSmall - Metrics.spacingMedium * 2) : 0
                    text: taskItem.modelData.title
                    variant: "label"
                    strong: true
                    elide: Text.ElideRight
                }
            }

            HoverHandler {
                id: taskHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: {
                    taskItem.forceActiveFocus(Qt.MouseFocusReason);
                    windowModel.activate(taskItem.modelData);
                }
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                        || event.key === Qt.Key_Space) {
                    windowModel.activate(taskItem.modelData);
                    event.accepted = true;
                }
            }

            Accessible.role: Accessible.Button
            Accessible.name: I18n.tr("menubar.active_window.app_accessible", {
                "name": taskItem.modelData.name,
                "title": taskItem.modelData.title,
                "count": taskItem.modelData.windowCount
            })
            Accessible.focusable: true
        }
    }
}
