pragma ComponentBehavior: Bound
// Protected Spotlight vertical slice.

import QtQuick
import qs.Titonium.Theme
import qs.Titonium.Shared as Controls
import qs.Titonium.Core.Runtime
import "SpotlightVisual.js" as SpotlightVisual

FocusScope {
    id: root

    required property var application
    property bool selected: false
    signal triggered()

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed

    activeFocusOnTab: true

    Rectangle {
        id: tileFrame
        anchors.centerIn: parent
        width: Math.min(132, parent.width - Metrics.spacingSmall)
        height: Math.min(120, parent.height - Metrics.spacingSmall)
        radius: Metrics.radiusLarge
        color: root.selected || root.hovered || root.pressed || root.activeFocus
            ? Theme.surfaceInteractive : "transparent"
        border.width: root.selected || root.activeFocus ? Metrics.borderWidth : 0
        border.color: root.activeFocus ? Theme.focus : Theme.accent
        Behavior on color { ColorAnimation { duration: Motion.fast } }

        Column {
            anchors.centerIn: parent
            width: parent.width - Metrics.spacingMedium * 2
            spacing: Metrics.spacingSmall

            Item {
                width: parent.width
                height: 64

                Controls.SystemIcon {
                    anchors.centerIn: parent
                    sourceName: root.application.icon || ""
                    fallbackName: SpotlightVisual.fallbackIcon(root.application.categories)
                    size: SpotlightVisual.appIconSize()
                    tone: "secondary"
                    accessibleName: ""
                }
            }

            Controls.TextLabel {
                width: parent.width
                text: root.application.name
                variant: "label"
                strong: root.selected
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.NoWrap
                maximumLineCount: 1
                elide: Text.ElideRight
            }
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
