pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root

    required property var application
    property bool showSubtitle: true
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
        anchors.fill: parent
        anchors.margins: Metrics.spacingSmall
        spacing: Metrics.spacingSmall

        Item {
            width: parent.width
            height: 42

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
            variant: "body"
            strong: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Controls.TextLabel {
            visible: root.showSubtitle
            width: parent.width
            text: root.application.subtitle || I18n.tr("launcher.application")
            variant: "caption"
            tone: "secondary"
            horizontalAlignment: Text.AlignHCenter
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
    Accessible.name: I18n.tr("launcher.launch_accessible", { "name": root.application.name })
    Accessible.focusable: true
}
