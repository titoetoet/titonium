pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Shared.styles
Item {
    id: root
    required property var paint
    required property var geometry
    required property var motion
    PaintTransition {
        id: stateTransition
        objectName: "styleStateTransition"
        targetValue: root.paint.stateLayerOpacity
        motion: root.motion
    }
    objectName: "neumorphismPaint"
    readonly property color lightShadow: paint.light ? "#ffffff" : "#69717d"
    readonly property color darkShadow: paint.light ? "#657185" : "#020407"
    SoftShadow {
        objectName: "neumoLightShadow"
        anchors.fill: parent; x: -3; y: -3
        anchors.leftMargin: -3; anchors.rightMargin: 3; anchors.topMargin: -3; anchors.bottomMargin: 3
        geometry: root.geometry; tint: root.lightShadow; strength: root.paint.inset ? 0 : root.paint.shadowStrength * (root.paint.hovered ? .8 : 1); spread: 5
    }
    SoftShadow {
        objectName: "neumoDarkShadow"
        anchors.fill: parent
        anchors.leftMargin: 3; anchors.rightMargin: -3; anchors.topMargin: 3; anchors.bottomMargin: -3
        geometry: root.geometry; tint: root.darkShadow; strength: root.paint.inset ? 0 : root.paint.shadowStrength * (root.paint.hovered ? .8 : 1); spread: 5
    }
    PaintShape {
        id: body
        anchors.fill: parent
        geometry: root.geometry
        color: root.paint.fill
        border.color: root.paint.outline
        border.width: root.paint.borderStrength > 0 ? Math.min(1, root.paint.borderStrength) : 0
    }
    PaintShape {
        objectName: "neumoInset"
        anchors.fill: parent; geometry: root.geometry
        visible: root.paint.inset
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.darkShadow, root.paint.depthStrength * .65) }
            GradientStop { position: .24; color: "transparent" }
            GradientStop { position: .78; color: "transparent" }
            GradientStop { position: 1; color: Qt.alpha(root.lightShadow, root.paint.depthStrength * .65) }
        }
        border.width: root.paint.depthStrength > 0 ? 1 : 0
        border.color: Qt.alpha(root.darkShadow, root.paint.depthStrength * .3)
    }
    PaintShape {
        anchors.fill: parent; geometry: root.geometry
        color: root.paint.foreground; opacity: stateTransition.value * .25
    }
}
