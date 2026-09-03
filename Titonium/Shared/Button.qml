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
    property int iconSize: 20
    property int labelPixelSize: 0
    property int backgroundRadius: Metrics.radiusSmall
    property int contentAlignment: Qt.AlignHCenter
    property color iconColor: root.foregroundColor
    property bool iconSpinning: false
    property bool iconHoverMotion: false
    property bool backgroundVisible: true
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
    scale: root.pressed && !root.iconHoverMotion && !Motion.reduced ? 0.96 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: Motion.fast
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.backgroundVisible
        radius: root.backgroundRadius
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
        Icon {
            id: actionIcon
            visible: root.iconName.length > 0
            name: root.iconName
            size: root.iconSize
            color: root.iconColor
            scale: Motion.reduced ? 1 : (root.iconHoverMotion && root.pressed ? 0.96
                : (root.iconHoverMotion && root.hovered ? 1.08 : 1))
            transform: Translate {
                y: !Motion.reduced && root.iconHoverMotion && root.hovered ? -1 : 0

                Behavior on y {
                    NumberAnimation { duration: Motion.reduced ? 0 : 140; easing.type: Easing.OutCubic }
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Motion.reduced ? 0 : 140
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.springDamped
                }
            }

            RotationAnimator {
                target: actionIcon
                running: root.iconSpinning && actionIcon.visible
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                onStopped: actionIcon.rotation = 0
            }
        }
        TextLabel {
            visible: root.label.length > 0
            text: root.label
            variant: "label"
            color: root.foregroundColor
            font.pixelSize: root.labelPixelSize > 0 ? root.labelPixelSize : Typography.labelSize
        }
    }

    HoverHandler { id: hoverHandler; enabled: root.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        id: tapHandler
        enabled: root.enabled
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.activate();
        }
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
