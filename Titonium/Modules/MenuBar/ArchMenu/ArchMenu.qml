pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation
import "ArchMenuModel.js" as ArchMenuModel

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""

    anchors.fill: parent
    focus: true

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    function close(): void {
        SurfaceCoordinator.close(root.ownerId);
    }

    function openSessionConfirmation(actionId: string): void {
        if (!ArchMenuModel.isSessionAction(actionId)) {
            Logger.warn("arch-menu", "unsupported session action: " + actionId);
            return;
        }
        const confirmationOwner = "session-confirm:" + root.screen.name + ":" + actionId;
        SurfaceCoordinator.open(confirmationOwner, {
            "source": Qt.resolvedUrl("SessionConfirmationSurface.qml"),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": confirmationOwner,
            "actionId": actionId
        }, root.screen);
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
            root.openSessionConfirmation(item.id);
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
        height: 308
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Metrics.barHeight + Metrics.spacingSmall
        anchors.leftMargin: Metrics.barPadding
        padding: Metrics.spacingSmall

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

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: root.forceActiveFocus(Qt.PopupFocusReason)
}
