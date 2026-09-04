pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Hyprland
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import "WorkspaceVisualRules.js" as WorkspaceVisualRules

Item {
    id: root

    required property var screen
    readonly property int count: Preferences.bar.workspaceCount
    readonly property int emptySlotWidth: 24
    readonly property int appIconSize: 17
    readonly property int appSpacing: 3
    readonly property int activeWorkspaceId: HyprlandService.focusedWorkspaceIdValue
    readonly property var items: HyprlandService.workspaceSnapshotForId(
        root.count, root.activeWorkspaceId)
    readonly property color inactiveColor: Theme.light ? "#e5e7eb" : "#2b303b"
    property bool selectionReady: false
    property int visualWorkspaceId: 0

    implicitWidth: workspaceRow.implicitWidth + Metrics.spacingSmall * 2
    implicitHeight: Metrics.widgetHeight

    function activateRelative(delta: int): void {
        const id = Math.max(1, root.activeWorkspaceId + delta);
        root.activateWorkspace(id);
    }

    function activateWorkspace(workspaceId: int): void {
        if (workspaceId < 1 || workspaceId === root.activeWorkspaceId)
            return;
        root.moveSelectionHighlight(workspaceId);
        HyprlandService.activateWorkspace(workspaceId);
    }

    function selectionGeometry(workspaceId: int): var {
        let x = workspaceRow.x;
        for (let index = 0; index < root.items.length; index++) {
            const item = root.items[index];
            const width = item.occupied
                ? WorkspaceVisualRules.occupiedWidth(item.apps.length,
                    root.appIconSize, root.appSpacing)
                : root.emptySlotWidth;
            if (item.id === workspaceId)
                return { "x": x, "width": width };
            x += width + workspaceRow.spacing;
        }
        return null;
    }

    function moveSelectionHighlight(workspaceId: int): void {
        const target = root.selectionGeometry(workspaceId);
        if (!target)
            return;
        const targetX = target.x;
        const targetWidth = target.width;
        const alreadyAligned = Math.abs(selectionHighlight.x - targetX) < 0.5
            && Math.abs(selectionHighlight.width - targetWidth) < 0.5;
        if (WorkspaceVisualRules.shouldSkipSelectionMove(root.selectionReady,
                root.visualWorkspaceId, workspaceId,
                selectionMotion.running, alreadyAligned))
            return;
        root.visualWorkspaceId = workspaceId;
        if (!root.selectionReady || Motion.reduced) {
            selectionMotion.stop();
            selectionHighlight.x = targetX;
            selectionHighlight.width = targetWidth;
            root.selectionReady = true;
            return;
        }
        const currentLeft = selectionHighlight.x;
        const currentRight = currentLeft + selectionHighlight.width;
        const targetRight = targetX + targetWidth;
        selectionMotion.stop();
        stretchX.from = currentLeft;
        stretchX.to = Math.min(currentLeft, targetX);
        stretchWidth.from = selectionHighlight.width;
        stretchWidth.to = Math.max(currentRight, targetRight) - Math.min(currentLeft, targetX);
        settleX.from = stretchX.to;
        settleX.to = targetX;
        settleWidth.from = stretchWidth.to;
        settleWidth.to = targetWidth;
        selectionMotion.start();
    }

    onItemsChanged: Qt.callLater(() => root.moveSelectionHighlight(root.activeWorkspaceId))
    onActiveWorkspaceIdChanged: Qt.callLater(() => root.moveSelectionHighlight(root.activeWorkspaceId))
    Component.onCompleted: Qt.callLater(() => root.moveSelectionHighlight(root.activeWorkspaceId))

    Rectangle {
        id: selectionHighlight
        z: 0
        y: (root.height - height) / 2
        width: 0
        height: WorkspaceVisualRules.pillHeight(true)
        radius: height / 2
        color: Theme.workspaceActivePalette[0]
    }

    SequentialAnimation {
        id: selectionMotion

        ParallelAnimation {
            id: stretchPhase
            NumberAnimation {
                id: stretchX
                target: selectionHighlight
                property: "x"
                duration: 105
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: stretchWidth
                target: selectionHighlight
                property: "width"
                duration: 105
                easing.type: Easing.OutCubic
            }
        }
        ParallelAnimation {
            id: settlePhase
            NumberAnimation {
                id: settleX
                target: selectionHighlight
                property: "x"
                duration: 115
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                id: settleWidth
                target: selectionHighlight
                property: "width"
                duration: 115
                easing.type: Easing.InOutCubic
            }
        }
    }

    Row {
        id: workspaceRow
        z: 1
        anchors.centerIn: parent
        spacing: Metrics.spacingSmall

        Repeater {
            model: root.items

            Item {
                id: workspaceItem
                required property var modelData
                readonly property bool visuallyActive:
                    workspaceItem.modelData.id === root.visualWorkspaceId
                readonly property int occupiedWidth: WorkspaceVisualRules.occupiedWidth(
                    workspaceItem.modelData.apps.length, root.appIconSize, root.appSpacing)
                readonly property color baseColor: root.inactiveColor
                width: workspaceItem.modelData.occupied
                    ? workspaceItem.occupiedWidth : root.emptySlotWidth
                height: WorkspaceVisualRules.slotHeight()
                Accessible.role: Accessible.Button
                Accessible.name: I18n.tr("menubar.workspace.accessible", {
                    id: workspaceItem.modelData.id,
                    state: workspaceItem.modelData.active
                        ? I18n.tr("menubar.workspace.active")
                        : (workspaceItem.modelData.occupied
                            ? I18n.tr("menubar.workspace.occupied") : "")
                })

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: workspaceItem.modelData.occupied && !workspaceItem.visuallyActive
                    height: WorkspaceVisualRules.pillHeight(workspaceItem.visuallyActive)
                    radius: Metrics.radiusLarge
                    color: hoverHandler.hovered
                        ? Qt.lighter(workspaceItem.baseColor, 1.12) : workspaceItem.baseColor
                    opacity: 0.76
                    border.width: workspaceItem.modelData.urgent ? Metrics.borderWidth : 0
                    border.color: workspaceItem.modelData.urgent ? Theme.warning : "transparent"

                    Behavior on opacity {
                        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: !workspaceItem.modelData.occupied
                    width: 7
                    height: width
                    radius: width / 2
                    color: hoverHandler.hovered
                        ? Qt.lighter(workspaceItem.visuallyActive
                            ? Theme.accentText : Theme.textSecondary, 1.12)
                        : (workspaceItem.visuallyActive ? Theme.accentText : Theme.textSecondary)
                    border.width: workspaceItem.modelData.urgent ? Metrics.borderWidth : 0
                    border.color: Theme.warning
                }

                Row {
                    anchors.centerIn: parent
                    spacing: root.appSpacing
                    visible: workspaceItem.modelData.occupied

                    Repeater {
                        model: workspaceItem.modelData.apps

                        Shared.SystemIcon {
                            required property var modelData
                            sourceName: modelData.icon
                            fallbackName: modelData.fallbackIcon || "apps"
                            size: root.appIconSize
                            tone: "primary"
                            accessibleName: ""
                            scale: Motion.reduced ? 1 : (workspaceTap.pressed ? 0.96
                                : (hoverHandler.hovered ? 1.08 : 1))
                            transform: Translate { y: !Motion.reduced && hoverHandler.hovered ? -1 : 0 }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Motion.reduced ? 0 : 140
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.springDamped
                                }
                            }
                        }
                    }
                }

                Behavior on width {
                    NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
                }

                HoverHandler { id: hoverHandler; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: workspaceTap
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.activateWorkspace(workspaceItem.modelData.id)
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
}
