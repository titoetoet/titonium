pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design

FocusScope {
    id: root

    property string label: ""
    property string iconName: ""
    property string variant: "secondary"
    property string size: "medium"
    property bool checkable: false
    property bool checked: false
    property bool selected: false
    property string accessibleName: root.label.length > 0 ? root.label : root.iconName
    signal triggered()

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed
    readonly property int controlHeight: root.size === "small" ? Metrics.controlHeightSmall : Metrics.controlHeight
    readonly property color foregroundColor: {
        if (!root.enabled)
            return Theme.textDisabled;
        if (root.variant === "primary")
            return Theme.accentText;
        if (root.variant === "danger")
            return root.pressed ? Theme.background : Theme.danger;
        return Theme.textPrimary;
    }
    readonly property color backgroundColor: {
        if (root.variant === "primary")
            return root.pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent;
        if (root.variant === "danger")
            return root.pressed ? Theme.danger : (root.hovered ? Theme.surfaceInteractive : Theme.surfaceElevated);
        if (root.variant === "quiet")
            return root.hovered || root.pressed || root.checked || root.selected ? Theme.surfaceInteractive : "transparent";
        return root.pressed || root.hovered || root.checked || root.selected ? Theme.surfaceInteractive : Theme.surfaceElevated;
    }

    function activate(): void {
        if (!root.enabled)
            return;
        if (root.checkable)
            root.checked = !root.checked;
        root.triggered();
    }

    implicitWidth: Math.max(root.controlHeight, contentRow.implicitWidth + Metrics.spacingMedium * 2)
    implicitHeight: root.controlHeight
    activeFocusOnTab: root.enabled
    opacity: root.enabled ? 1.0 : 0.55

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusSmall
        color: root.backgroundColor
        border.width: Metrics.borderWidth
        border.color: root.activeFocus
            ? Theme.focus
            : (root.variant === "danger" ? Theme.danger : (root.variant === "quiet" ? "transparent" : Theme.border))

        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: root.label.length > 0 && root.iconName.length > 0 ? Metrics.spacingSmall : 0

        Icon {
            visible: root.iconName.length > 0
            name: root.iconName
            size: 20
            tone: root.variant === "primary" ? "primary" : (root.variant === "danger" ? "danger" : "primary")
            color: root.foregroundColor
        }

        TextLabel {
            visible: root.label.length > 0
            text: root.label
            variant: "label"
            color: root.foregroundColor
        }
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        enabled: root.enabled
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.activate();
        }
    }

    Keys.onPressed: event => {
        if (root.enabled && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            root.activate();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Accessible.checkable: root.checkable
    Accessible.checked: root.checked
    Accessible.selected: root.selected
}
