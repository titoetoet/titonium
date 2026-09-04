pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Notifications
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property var invoker: root.descriptor?.invoker || null
    readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing
    readonly property real availableHeight: Math.max(0,
        root.height - root.panelTop - Metrics.barPadding)
    readonly property real listHeight: NotificationCoordinator.history.length === 0
        ? 112 : Math.min(historyList.contentHeight, 460)
    readonly property real contentHeight: headerRow.implicitHeight + Metrics.borderWidth
        + root.listHeight + Metrics.spacingMedium * 2 + panel.padding * 2

    anchors.fill: parent
    focus: true

    property bool closing: false
    property bool focusReturned: false
    property var closingDescriptor: null
    property var closingScreen: null
    property var closingInvoker: null

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0
            && local.x <= item.width && local.y <= item.height;
    }

    function returnFocus(): void {
        if (root.focusReturned)
            return;
        const ownedDescriptor = root.closingDescriptor || root.descriptor;
        const ownedScreen = root.closingScreen || root.screen;
        if (SurfaceManager.active
                && !SurfaceManager.matches(root.ownerId, ownedDescriptor, ownedScreen))
            return;
        root.focusReturned = true;
        const target = root.closingInvoker || root.invoker;
        if (target?.forceActiveFocus)
            target.forceActiveFocus(Qt.PopupFocusReason);
    }

    function finishClose(): void {
        if (!root.closingDescriptor || !SurfaceManager.matches(
                root.ownerId, root.closingDescriptor, root.closingScreen))
            return;
        root.returnFocus();
        SurfaceManager.closeOwned(root.ownerId,
            root.closingDescriptor, root.closingScreen);
    }

    function reopenIfReplaced(): void {
        if (!root.closing || root.descriptor === root.closingDescriptor)
            return;
        panelExit.stop();
        root.closing = false;
        root.closingDescriptor = null;
        root.closingScreen = null;
        root.closingInvoker = null;
        root.focusReturned = false;
        if (!Motion.reduced)
            panelEntrance.restart();
        panel.forceActiveFocus(Qt.PopupFocusReason);
    }

    function close(): void {
        if (root.closing || !SurfaceManager.beginClose(
                root.ownerId, root.descriptor, root.screen))
            return;
        root.closingDescriptor = root.descriptor;
        root.closingScreen = root.screen;
        root.closingInvoker = root.invoker;
        root.closing = true;
        if (Motion.reduced) {
            root.finishClose();
            return;
        }
        panelExit.restart();
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(panel, eventPoint.position))
                    root.close();
            }
        }
    }

    Shared.Panel {
        id: panel
        width: 420
        height: Math.min(560, root.availableHeight, root.contentHeight)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.panelTop
        anchors.rightMargin: Metrics.barPadding
        customColor: Theme.surface
        clipContent: true
        transformOrigin: Item.TopRight
        opacity: Motion.reduced ? 1 : 0
        scale: Motion.reduced ? 1 : 0.94
        transform: Translate {
            id: panelOffset
            y: Motion.reduced ? 0 : -12
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Metrics.spacingMedium

            RowLayout {
                id: headerRow
                Layout.fillWidth: true
                spacing: Metrics.spacingMedium

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: I18n.tr("notification.panel.title")
                    variant: "title"
                    strong: true
                    Accessible.role: Accessible.Heading
                }

                Shared.Button {
                    visible: NotificationCoordinator.history.length > 0
                    label: I18n.tr("notification.panel.clear_all")
                    iconName: "clear_all"
                    variant: "quiet"
                    size: "small"
                    onTriggered: NotificationCoordinator.dismissAll()
                }

                Shared.Button {
                    iconName: "close"
                    variant: "quiet"
                    size: "small"
                    accessibleName: I18n.tr("notification.panel.close")
                    onTriggered: root.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.borderWidth
                color: Theme.border
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.listHeight
                Layout.minimumHeight: 0

                ListView {
                    id: historyList
                    anchors.fill: parent
                    model: NotificationCoordinator.history
                    clip: true
                    spacing: Metrics.spacingSmall
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: true

                    delegate: NotificationHistoryRow {
                        required property var modelData
                        width: historyList.width
                        notification: modelData
                    }
                }

                Shared.TextLabel {
                    anchors.centerIn: parent
                    visible: NotificationCoordinator.history.length === 0
                    text: I18n.tr("notification.panel.empty")
                    tone: "secondary"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    ParallelAnimation {
        id: panelEntrance
        running: !Motion.reduced

        NumberAnimation {
            target: panel
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 0.94
            to: 1
            duration: 220
            easing.bezierCurve: Motion.springDamped
        }
        NumberAnimation {
            target: panelOffset
            property: "y"
            from: -12
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: panelExit

        NumberAnimation {
            target: panel
            property: "opacity"
            from: 1
            to: 0
            duration: 120
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 1
            to: 0.96
            duration: 130
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panelOffset
            property: "y"
            from: 0
            to: -8
            duration: 130
            easing.type: Easing.InCubic
        }
        onFinished: root.finishClose()
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.close();
            event.accepted = true;
        }
    }

    onDescriptorChanged: root.reopenIfReplaced()
    Component.onCompleted: {
        NotificationCoordinator.panelMounted(root.ownerId);
        NotificationCoordinator.markAllRead();
        panel.forceActiveFocus(Qt.PopupFocusReason);
    }
    Component.onDestruction: {
        NotificationCoordinator.panelUnmounted(root.ownerId);
        root.returnFocus();
    }
}
