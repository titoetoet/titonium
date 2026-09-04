pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.right
import qs.Titonium.Services.Notifications
import "NotificationPanelLifecycle.js" as NotificationPanelLifecycle

Item {
    id: root

    property real availableViewportHeight: 440
    readonly property real implicitContentWidth:
        historyContent.implicitContentWidth + 32
    readonly property real implicitContentHeight: Math.min(
        root.availableViewportHeight, historyContent.implicitContentHeight + 32)
    implicitWidth: root.implicitContentWidth
    implicitHeight: root.implicitContentHeight
    readonly property string ownerId:
        RightPillCoordinator.connectedDescriptor?.feature === "notifications"
            ? RightPillCoordinator.connectedOwnerId : ""
    property bool loaded: false
    property string mountedOwnerId: ""

    signal dismissRequested()

    function syncPanelMount(): void {
        if (!root.loaded)
            return;
        const plan = NotificationPanelLifecycle.transition(
            root.mountedOwnerId, root.ownerId);
        if (plan.unmountOwnerId)
            NotificationCoordinator.panelUnmounted(plan.unmountOwnerId);
        root.mountedOwnerId = plan.mountedOwnerId;
        if (plan.mountOwnerId)
            NotificationCoordinator.panelMounted(plan.mountOwnerId);
        if (plan.markRead)
            NotificationCoordinator.markAllRead();
    }

    function teardownPanelMount(): void {
        const plan = NotificationPanelLifecycle.teardown(root.mountedOwnerId);
        root.mountedOwnerId = plan.mountedOwnerId;
        if (plan.unmountOwnerId)
            NotificationCoordinator.panelUnmounted(plan.unmountOwnerId);
    }

    NotificationHistoryContent {
        id: historyContent
        anchors.fill: parent
        anchors.margins: 16
        onDismissRequested: root.dismissRequested()
    }

    onOwnerIdChanged: root.syncPanelMount()
    Component.onCompleted: {
        root.loaded = true;
        root.syncPanelMount();
    }
    Component.onDestruction: root.teardownPanelMount()
}
