pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme

FocusScope {
    id: root
    property var tokens: Theme.tokens
    readonly property int interactionDuration: tokens.reducedMotion ? 0 : Math.round((tokens.design?.controlMotion?.durationMs || 100) * (tokens.motionScale || 1))
    readonly property bool legacyPaint: tokens.legacy !== false

    property bool checked: false
    property string accessibleName: ""
    signal toggled(bool checked)

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed

    implicitWidth: 40
    implicitHeight: 22
    activeFocusOnTab: root.enabled
    opacity: root.enabled ? 1 : 0.5

    function activate(): void {
        if (root.enabled)
            root.toggled(!root.checked);
    }

    Rectangle {
        anchors.fill: parent
        visible: root.legacyPaint
        radius: height / 2
        color: root.checked ? root.tokens.colors.accent
            : (root.hovered ? root.tokens.colors.surfaceInteractive : root.tokens.colors.surfaceElevated)
        border.width: root.activeFocus ? Metrics.borderWidth : 0
        border.color: root.activeFocus ? root.tokens.colors.focus : "transparent"
        Behavior on color { ColorAnimation { duration: root.legacyPaint ? Motion.fast : root.interactionDuration } }
    }

    StylePaint {
        objectName: "toggleStyleTrack"
        anchors.fill: parent
        visible: !root.legacyPaint
        tokens: root.tokens
        role: "toggle-track"
        radius: root.tokens.design.renderer === "modern-flat" ? 5 : height / 2
        interaction: ({enabled:root.enabled,hovered:root.hovered,pressed:root.pressed,primary:root.checked,focused:root.activeFocus})
    }

    Rectangle {
        id: thumb
        width: 16
        height: 16
        radius: width / 2
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.legacyPaint ? (root.checked ? root.tokens.colors.accentText : root.tokens.colors.textSecondary) : "transparent"
        StylePaint {
            anchors.fill: parent
            visible: !root.legacyPaint
            tokens: root.tokens
            role: "toggle-thumb"
            radius: root.tokens.design.renderer === "modern-flat" ? 3 : width / 2
            customColor: root.checked ? root.tokens.colors.accentText : root.tokens.colors.textSecondary
            outlined: false
        }
        Behavior on x { NumberAnimation { duration: root.legacyPaint ? Motion.fast : root.interactionDuration; easing.type: Easing.OutCubic } }
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
        if (root.enabled && (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter)) {
            root.activate();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.accessibleName
    Accessible.focusable: root.enabled
    Accessible.checkable: true
    Accessible.checked: root.checked
}
