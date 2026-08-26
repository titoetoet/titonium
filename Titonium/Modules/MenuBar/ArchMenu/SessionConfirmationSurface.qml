pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation
import qs.Titonium.Platform.System

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    property bool launchPending: false
    property string failureMessage: ""
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property string actionId: root.descriptor?.actionId || ""

    anchors.fill: parent
    focus: true

    function close(): void {
        if (!root.launchPending)
            SurfaceCoordinator.close(root.ownerId);
    }

    function confirm(actionId: string): void {
        if (root.launchPending || actionId.length === 0 || actionId !== root.actionId)
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

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        TapHandler { onTapped: root.close() }
    }

    Controls.Panel {
        id: panel
        z: 1
        anchors.centerIn: parent
        width: 420
        height: Math.max(240, Math.min(320,
            confirmation.implicitHeight + Metrics.spacingLarge * 2))
        clipContent: true

        Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: confirmation.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            SessionConfirmation {
                id: confirmation
                width: parent.width
                actionId: root.actionId
                busy: root.launchPending
                failureMessage: root.failureMessage
                onCancelled: root.close()
                onConfirmed: actionId => root.confirm(actionId)
            }
        }
    }

    Connections {
        target: SessionActions

        function onActionStarted(action: string): void {
            if (action === root.actionId)
                SurfaceCoordinator.forceClose(root.ownerId);
        }

        function onActionFailed(action: string, error: string): void {
            if (action !== root.actionId)
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
