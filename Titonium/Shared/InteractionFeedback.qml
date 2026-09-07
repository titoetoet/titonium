pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.Titonium.Theme
import "InteractionState.js" as InteractionState

// Presentation only: no input handlers, effects, timers or layout mutations.
Item {
    id: root
    property bool hovered: false
    property bool pressed: false
    property bool selected: false
    property bool warning: false
    property bool focused: false
    property real radius: Metrics.radiusSmall
    readonly property real hoverStrength: 0.12 + 0.10 * Theme.material.sheenStrength
    readonly property var feedback: InteractionState.feedback(root.enabled,
        root.hovered, root.pressed, root.selected, root.warning, root.focused)

    StylePaint {
        anchors.fill: parent
        visible: !Theme.legacy
        tokens: Theme.tokens
        role: "menu-row"
        radius: root.radius
        outlined: false
        showFocus: false
        interaction: ({enabled:root.enabled,quiet:true,hovered:root.hovered,pressed:root.pressed})
    }

    Rectangle {
        visible: Theme.legacy
        anchors.fill: parent
        radius: root.radius
        color: Theme.textPrimary
        opacity: root.feedback.press ? 0.12 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: root.feedback.hover
        visible: Theme.legacy && opacity > 0
        Behavior on opacity { NumberAnimation { duration: Motion.normal; easing.type: Easing.OutCubic } }
        ShapePath {
            strokeWidth: 0
            fillGradient: RadialGradient {
                centerX: root.width / 2
                centerY: root.height
                focalX: centerX
                focalY: centerY
                centerRadius: Math.max(root.width * 0.65, root.height)
                GradientStop { position: 0; color: Qt.alpha(Theme.textPrimary, root.hoverStrength) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathRectangle { width: root.width; height: root.height; radius: root.radius }
        }
    }

    // A steady short mark communicates selection independently of the hover light.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        width: Math.min(12, root.width * 0.4)
        height: 2
        radius: 1
        color: root.feedback.warning ? Theme.warning : Theme.accent
        visible: root.feedback.active || root.feedback.warning
    }

    Rectangle {
        objectName: "appearanceFocus"
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: Theme.focus
        visible: root.feedback.focus
    }
}
