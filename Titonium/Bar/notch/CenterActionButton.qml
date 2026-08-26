pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

FocusScope {
    id: root
    required property var descriptor
    signal actionRequested(string intent, string feedbackKey)

    readonly property bool hovered: hoverHandler.hovered
    readonly property string actionLabel: I18n.tr(root.descriptor.labelKey)
    readonly property string unavailableLabel: I18n.tr("center_notch.action.unavailable")

    function activate(): void {
        root.actionRequested(root.descriptor.intent, "center_notch.action.unavailable");
    }

    implicitHeight: 92
    implicitWidth: 128
    activeFocusOnTab: true

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusMedium
        color: root.hovered ? Theme.surfaceInteractive : Theme.surfaceElevated
        border.width: Metrics.borderWidth
        border.color: root.activeFocus ? Theme.focus : Theme.border
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Metrics.spacingMedium
        spacing: Metrics.spacingSmall

        Shared.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: root.descriptor.icon
            size: 26
            tone: "secondary"
        }
        Shared.TextLabel {
            width: parent.width
            text: root.actionLabel
            variant: "label"
            strong: true
            elide: Text.ElideRight
            maximumLineCount: 1
            horizontalAlignment: Text.AlignHCenter
        }
        Shared.TextLabel {
            width: parent.width
            text: root.unavailableLabel
            variant: "caption"
            tone: "secondary"
            elide: Text.ElideRight
            maximumLineCount: 1
            horizontalAlignment: Text.AlignHCenter
        }
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.activate();
        }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter) {
            root.activate();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.actionLabel + ", " + root.unavailableLabel
    Accessible.focusable: true
}
