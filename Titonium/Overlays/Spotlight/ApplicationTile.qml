pragma ComponentBehavior: Bound
// Protected Spotlight vertical slice.

import QtQuick
import qs.Titonium.Theme
import qs.Titonium.Shared as Controls
import qs.Titonium.Core.Runtime

FocusScope {
    id: root

    required property var application
    signal triggered()

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed

    activeFocusOnTab: true

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusMedium
        color: root.hovered || root.pressed || root.activeFocus ? Theme.surfaceInteractive : "transparent"
        border.width: root.activeFocus ? Metrics.borderWidth : 0
        border.color: Theme.focus
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - Metrics.spacingSmall * 2
        spacing: Metrics.spacingXSmall

        Item {
            width: parent.width
            height: 48

            Image {
                id: appIcon
                anchors.centerIn: parent
                width: 40
                height: 40
                source: root.application.icon || ""
                sourceSize.width: 48
                sourceSize.height: 48
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }

            Controls.Icon {
                anchors.centerIn: parent
                visible: appIcon.status !== Image.Ready
                name: "apps"
                size: 28
                tone: "secondary"
                accessibleName: ""
            }
        }

        Controls.TextLabel {
            width: parent.width
            text: root.application.name
            variant: "label"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.triggered();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.triggered();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr("spotlight.launch_accessible", { "name": root.application.name })
    Accessible.focusable: true
}
