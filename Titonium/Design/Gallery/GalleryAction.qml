pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design

Rectangle {
    id: root

    property string label: ""
    property string kind: "default"
    property bool controlEnabled: true
    signal triggered()

    implicitWidth: actionLabel.implicitWidth + Metrics.spacingMedium * 2
    implicitHeight: Metrics.controlHeight
    radius: Metrics.radiusSmall
    color: {
        if (!root.controlEnabled)
            return Theme.surfaceInteractive;
        if (root.kind === "primary")
            return Theme.accent;
        return pointer.pressed || hover.hovered ? Theme.surfaceInteractive : Theme.surfaceElevated;
    }
    border.width: Metrics.borderWidth
    border.color: root.kind === "danger" ? Theme.danger : (root.kind === "focus" ? Theme.focus : Theme.border)
    opacity: root.controlEnabled ? 1.0 : 0.55

    Text {
        id: actionLabel
        anchors.centerIn: parent
        text: root.label
        color: root.kind === "primary" ? Theme.accentText : (root.kind === "danger" ? Theme.danger : Theme.textPrimary)
        font.family: Typography.family
        font.pixelSize: Typography.labelSize
        font.weight: Typography.mediumWeight
        renderType: Text.NativeRendering
    }

    TapHandler {
        id: pointer
        enabled: root.controlEnabled
        onTapped: root.triggered()
    }

    HoverHandler { id: hover }

    Accessible.role: Accessible.Button
    Accessible.name: root.label
}
