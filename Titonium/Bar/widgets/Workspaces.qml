pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Hyprland
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root

    required property var screen
    property int count: 5
    readonly property int slotWidth: 28
    readonly property int activeWorkspaceId: HyprlandService.activeWorkspaceId(root.screen)
    readonly property var items: HyprlandService.workspaceSnapshot(root.screen, root.count)
    readonly property int activeIndex: {
        for (let index = 0; index < root.items.length; index++) {
            if (root.items[index]?.active === true)
                return index;
        }
        return 0;
    }
    property int previousActiveIndex: 0

    implicitWidth: root.slotWidth * root.count + Metrics.spacingXSmall * 2
    implicitHeight: Metrics.widgetHeight

    function activateRelative(delta: int): void {
        const id = Math.max(1, root.activeWorkspaceId + delta);
        HyprlandService.activateWorkspace(id);
    }

    Shared.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusSmall
    }

    Item {
        id: track
        width: root.slotWidth * root.count
        height: Metrics.controlHeightSmall - Metrics.spacingXSmall
        anchors.centerIn: parent

        Repeater {
            model: root.items

            Rectangle {
                required property int index
                required property var modelData
                visible: modelData.occupied && modelData.rangeStart === modelData.id
                x: index * root.slotWidth + 2
                anchors.verticalCenter: parent.verticalCenter
                width: (modelData.rangeEnd - modelData.rangeStart + 1) * root.slotWidth - 4
                height: 18
                radius: Metrics.radiusSmall
                color: Theme.surfaceInteractive
            }
        }

        Rectangle {
            id: activeHighlight
            x: root.activeIndex * root.slotWidth + 2
            anchors.verticalCenter: parent.verticalCenter
            width: root.slotWidth - 4
            height: 22
            radius: Metrics.radiusMedium
            color: Theme.accent
        }

        SequentialAnimation {
            id: activeTravel

            ParallelAnimation {
                NumberAnimation {
                    target: activeHighlight
                    property: "x"
                    to: Math.min(root.previousActiveIndex, root.activeIndex) * root.slotWidth + 2
                    duration: Math.round(Motion.fast / 2)
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: activeHighlight
                    property: "width"
                    to: (Math.abs(root.activeIndex - root.previousActiveIndex) + 1)
                        * root.slotWidth - 4
                    duration: Math.round(Motion.fast / 2)
                    easing.type: Easing.OutCubic
                }
            }

            ParallelAnimation {
                NumberAnimation {
                    target: activeHighlight
                    property: "x"
                    to: root.activeIndex * root.slotWidth + 2
                    duration: Math.round(Motion.fast / 2)
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: activeHighlight
                    property: "width"
                    to: root.slotWidth - 4
                    duration: Math.round(Motion.fast / 2)
                    easing.type: Easing.OutCubic
                }
            }

            onFinished: root.previousActiveIndex = root.activeIndex
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: root.items

                Item {
                    id: workspaceItem
                    required property var modelData
                    width: root.slotWidth
                    height: track.height
                    Accessible.role: Accessible.Button
                    Accessible.name: I18n.tr("menubar.workspace.accessible", {
                        id: workspaceItem.modelData.id,
                        state: workspaceItem.modelData.active
                            ? I18n.tr("menubar.workspace.active")
                            : (workspaceItem.modelData.occupied
                                ? I18n.tr("menubar.workspace.occupied") : "")
                    })

                    Shared.SystemIcon {
                        anchors.centerIn: parent
                        visible: workspaceItem.modelData.active
                            && workspaceItem.modelData.icon.length > 0
                        sourceName: workspaceItem.modelData.icon
                        fallbackName: "apps"
                        size: 16
                        tone: "primary"
                        accessibleName: ""
                    }

                    Shared.TextLabel {
                        anchors.centerIn: parent
                        visible: !workspaceItem.modelData.active
                            || workspaceItem.modelData.icon.length === 0
                        text: String(workspaceItem.modelData.id)
                        variant: "caption"
                        strong: workspaceItem.modelData.active
                        color: workspaceItem.modelData.active
                            ? Theme.accentText : Theme.textSecondary
                    }

                    Rectangle {
                        visible: workspaceItem.modelData.occupied
                            && !workspaceItem.modelData.active
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        width: 3
                        height: 3
                        radius: 2
                        color: workspaceItem.modelData.urgent
                            ? Theme.warning : Theme.textSecondary
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: HyprlandService.activateWorkspace(workspaceItem.modelData.id)
                    }
                }
            }
        }
    }

    WheelHandler {
        target: null
        onWheel: event => {
            if (event.angleDelta.y === 0)
                return;
            root.activateRelative(event.angleDelta.y > 0 ? -1 : 1);
            event.accepted = true;
        }
    }

    onActiveIndexChanged: {
        if (root.previousActiveIndex === root.activeIndex)
            return;
        activeTravel.restart();
    }

    Component.onCompleted: root.previousActiveIndex = root.activeIndex
}
