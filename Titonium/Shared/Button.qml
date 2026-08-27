pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme

FocusScope {
    id: root
    property string label: ""
    property string iconName: ""
    property string variant: "secondary"
    property string size: "medium"
    property bool checkable: false
    property bool checked: false
    property bool selected: false
    property bool showFocusRing: true
    property int contentAlignment: Qt.AlignHCenter
    property string accessibleName: root.label.length > 0 ? root.label : root.iconName
    signal triggered()

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed
    readonly property int controlHeight: root.size === "small"
        ? Metrics.controlHeightSmall : Metrics.controlHeight
    readonly property color foregroundColor: !root.enabled ? Theme.textDisabled
        : (root.variant === "primary" ? Theme.accentText
            : (root.variant === "danger" ? Theme.danger : Theme.textPrimary))
    readonly property color backgroundColor: root.variant === "primary" ? Theme.accent
        : (root.variant === "quiet"
            ? (root.hovered || root.pressed || root.checked || root.selected
                ? Theme.surfaceInteractive : "transparent")
            : (root.hovered || root.pressed || root.checked || root.selected
                ? Theme.surfaceInteractive : Theme.surfaceElevated))

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
        border.width: root.activeFocus && root.showFocusRing ? Metrics.borderWidth
            : (root.variant === "quiet" ? 0 : Metrics.borderWidth)
        border.color: root.activeFocus && root.showFocusRing ? Theme.focus
            : (root.variant === "quiet" ? "transparent" : Theme.border)
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Row {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        x: root.contentAlignment === Qt.AlignLeft ? Metrics.spacingMedium : (parent.width - width) / 2
        spacing: root.label.length > 0 && root.iconName.length > 0 ? Metrics.spacingSmall : 0
        Icon { visible: root.iconName.length > 0; name: root.iconName; size: 20; color: root.foregroundColor }
        TextLabel { visible: root.label.length > 0; text: root.label; variant: "label"; color: root.foregroundColor }
    }

    HoverHandler { id: hoverHandler; enabled: root.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        id: tapHandler
        enabled: root.enabled
        onTapped: { root.forceActiveFocus(Qt.MouseFocusReason); root.activate(); }
    }
    Keys.onPressed: event => {
        if (root.enabled && (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter)) {
            root.activate();
            event.accepted = true;
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Accessible.focusable: root.enabled
    Accessible.checkable: root.checkable
    Accessible.checked: root.checked
    Accessible.selected: root.selected
}
