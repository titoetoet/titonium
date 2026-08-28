pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Theme

FocusScope {
    id: root
    required property ShellScreen screenModel
    signal settingsRequested(var screen)
    readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing

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
                if (!root.pointInside(notch, eventPoint.position)
                        && !CenterNotchCoordinator.pinned)
                    CenterNotchCoordinator.close();
            }
        }
    }

    CenterNotch {
        id: notch
        width: Math.min(900, root.width - 32)
        height: Math.min(430, root.height - root.panelTop - Metrics.barPadding)
        anchors.top: parent.top
        anchors.topMargin: root.panelTop
        anchors.horizontalCenter: parent.horizontalCenter
        onSettingsRequested: root.settingsRequested(root.screenModel)
    }

    Keys.onEscapePressed: event => {
        CenterNotchCoordinator.close();
        event.accepted = true;
    }

    Component.onCompleted: notch.forceActiveFocus(Qt.PopupFocusReason)
}
