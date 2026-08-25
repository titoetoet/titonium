pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation
import qs.Titonium.Platform.System
import "ArchMenuModel.js" as ArchMenuModel

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    property string pendingAction: ""
    property bool launchPending: false
    property string failureMessage: ""
    readonly property string ownerId: root.descriptor?.ownerId || ""

    anchors.fill: parent
    focus: true

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    function close(): void {
        if (!root.launchPending)
            SurfaceCoordinator.close(root.ownerId);
    }

    function requestSessionAction(actionId: string): void {
        root.pendingAction = actionId;
        root.failureMessage = "";
        root.launchPending = false;
    }

    function cancelPendingAction(): void {
        if (root.launchPending)
            return;
        root.pendingAction = "";
        root.failureMessage = "";
    }

    function confirmPendingAction(actionId: string): void {
        if (root.launchPending || actionId.length === 0 || actionId !== root.pendingAction)
            return;
        if (!SurfaceCoordinator.guardOwner(root.ownerId)) {
            root.failureMessage = I18n.tr("session.error.start_failed");
            return;
        }
        const accepted = SessionActions.executeConfirmed(actionId);
        if (accepted) {
            if (SurfaceCoordinator.ownerId === root.ownerId)
                root.launchPending = true;
            return;
        }
        SurfaceCoordinator.releaseOwnerGuard(root.ownerId);
        root.failureMessage = I18n.tr(SessionActions.lastError);
    }

    function openAbout(): void {
        const aboutOwner = "about-titonium:" + root.screen.name;
        SurfaceCoordinator.open(aboutOwner, {
            "source": Qt.resolvedUrl("AboutTitonium.qml"),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": aboutOwner
        }, root.screen);
    }

    function openSettings(): void {
        const settingsOwner = "settings:" + root.screen.name;
        ConfigStore.beginPreview();
        SurfaceCoordinator.open(settingsOwner, {
            "source": Qt.resolvedUrl("../../Settings/SettingsCenter.qml"),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "cancelPreviewOnClose": true,
            "ownerId": settingsOwner
        }, root.screen);
    }

    function activateItem(item: var): void {
        const route = ArchMenuModel.routeFor(item);
        if (route === "confirm") {
            root.requestSessionAction(item.id);
            return;
        }
        if (route === "settings") {
            root.openSettings();
            return;
        }
        if (route === "about") {
            root.openAbout();
            return;
        }
        Logger.warn("arch-menu", "unknown item id: " + (item?.id || "<missing>"));
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

    Controls.Panel {
        id: panel
        z: 1
        width: 292
        height: root.pendingAction.length > 0 ? 268 : 308
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Metrics.barHeight + Metrics.spacingSmall
        anchors.leftMargin: Metrics.barPadding
        padding: Metrics.spacingSmall

        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: root.pendingAction.length > 0
                ? confirmationComponent : menuComponent
        }
    }

    Component {
        id: menuComponent

        Column {
            width: 276

            Repeater {
                model: ArchMenuModel.groups

                Column {
                    id: groupDelegate
                    required property var modelData
                    required property int index
                    width: 276

                    Repeater {
                        model: groupDelegate.modelData

                        ArchMenuItem {
                            required property var modelData
                            width: groupDelegate.width
                            itemData: modelData
                            initialFocus: modelData.id === "about"
                            enabled: !root.launchPending
                            onTriggered: item => root.activateItem(item)
                        }
                    }

                    Rectangle {
                        visible: groupDelegate.index < ArchMenuModel.groups.length - 1
                        width: parent.width
                        height: visible ? Metrics.borderWidth : 0
                        implicitHeight: Metrics.borderWidth
                        color: Theme.border
                        opacity: 0.7
                        Accessible.role: Accessible.Separator
                    }
                }
            }
        }
    }

    Component {
        id: confirmationComponent

        SessionConfirmation {
            width: 276
            actionId: root.pendingAction
            busy: root.launchPending
            failureMessage: root.failureMessage
            onCancelled: root.cancelPendingAction()
            onConfirmed: actionId => root.confirmPendingAction(actionId)
        }
    }

    Connections {
        target: SessionActions

        function onActionStarted(action: string): void {
            if (action === root.pendingAction)
                SurfaceCoordinator.forceClose(root.ownerId);
        }

        function onActionFailed(action: string, error: string): void {
            if (action !== root.pendingAction)
                return;
            SurfaceCoordinator.releaseOwnerGuard(root.ownerId);
            root.launchPending = false;
            root.failureMessage = I18n.tr(error);
        }
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: root.forceActiveFocus(Qt.PopupFocusReason)
}
