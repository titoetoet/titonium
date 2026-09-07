pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import qs.Titonium.Theme

FocusScope {
    id: root
    property var tokens: Theme.tokens
    readonly property bool legacyPaint: tokens.legacy !== false

    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0
    property string accessibleName: ""
    signal moved(real value)

    implicitWidth: 180
    implicitHeight: Metrics.controlHeight
    activeFocusOnTab: root.enabled

    QtControls.Slider {
        id: control

        anchors.fill: parent
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value
        enabled: root.enabled
        activeFocusOnTab: true
        Accessible.name: root.accessibleName
        onMoved: root.moved(control.value)

        background: Item {
            x: control.leftPadding
            y: control.topPadding + control.availableHeight / 2 - height / 2
            width: control.availableWidth
            height: root.legacyPaint ? 4 : (root.tokens.design.renderer === "material" ? 6 : 4)

            Rectangle {
                anchors.fill: parent
                visible: root.legacyPaint
                radius: height / 2
                color: root.tokens.colors.surfaceInteractive
            }

            StylePaint {
                objectName: "sliderStyleTrack"
                anchors.fill: parent
                visible: !root.legacyPaint
                tokens: root.tokens
                role: "slider-track"
                radius: height / 2
                interaction: ({enabled:root.enabled})
                showFocus: false
            }

            Rectangle {
                width: control.visualPosition * parent.width
                height: parent.height
                radius: height / 2
                color: root.enabled ? root.tokens.colors.accent : root.tokens.colors.textDisabled
            }
        }

        handle: Rectangle {
            x: control.leftPadding + control.visualPosition
                * (control.availableWidth - width)
            y: control.topPadding + control.availableHeight / 2 - height / 2
            width: 18
            height: 18
            radius: width / 2
            color: root.legacyPaint ? (root.enabled ? root.tokens.colors.textPrimary : root.tokens.colors.textDisabled) : "transparent"
            StylePaint {
                objectName: "sliderStyleThumb"
                anchors.fill: parent
                visible: !root.legacyPaint
                tokens: root.tokens
                role: "slider-thumb"
                radius: root.tokens.design.renderer === "modern-flat" ? 4 : width / 2
                customColor: root.enabled ? root.tokens.colors.textPrimary : root.tokens.colors.textDisabled
                interaction: ({enabled:root.enabled,pressed:control.pressed,hovered:control.hovered,focused:control.activeFocus})
            }
            border.width: control.activeFocus ? Metrics.borderWidth : 0
            border.color: root.tokens.colors.focus
        }
    }

}
