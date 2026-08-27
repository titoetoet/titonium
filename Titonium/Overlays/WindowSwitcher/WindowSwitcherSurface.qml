pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.WindowSwitcher
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null

    anchors.fill: parent
    focus: true

    function close(): void {
        WindowSwitcherService.cancel();
    }

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
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
        width: Math.min(760, Math.max(280, root.width - Metrics.spacingLarge * 4))
        height: 152
        anchors.centerIn: parent
        customColor: Theme.surface
        padding: Metrics.spacingLarge
        clipContent: true

        ListView {
            id: windowList
            anchors.fill: parent
            model: WindowSwitcherService.windows
            orientation: ListView.Horizontal
            spacing: Metrics.spacingMedium
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Motion.fast
            currentIndex: {
                const windows = WindowSwitcherService.windows;
                for (let index = 0; index < windows.length; index++) {
                    if (windows[index]?.id === WindowSwitcherService.selectedId)
                        return index;
                }
                return -1;
            }

            delegate: WindowSwitcherTile {
                required property var modelData
                window: modelData
            }
        }
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            WindowSwitcherService.accept();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            WindowSwitcherService.previous();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
            WindowSwitcherService.next();
            event.accepted = true;
        }
    }

    Component.onCompleted: root.forceActiveFocus(Qt.PopupFocusReason)
}
