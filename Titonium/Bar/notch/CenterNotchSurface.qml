pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

FocusScope {
    id: root
    required property ShellScreen screenModel

    anchors.fill: parent
    focus: true

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(notch, eventPoint.position))
                    CenterNotchCoordinator.close();
            }
        }
    }

    CenterNotch {
        id: notch
        width: Math.min(900, root.width - 32)
        height: Math.min(430, root.height - 64)
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Keys.onEscapePressed: event => {
        CenterNotchCoordinator.close();
        event.accepted = true;
    }

    Component.onCompleted: notch.forceActiveFocus(Qt.PopupFocusReason)
}
