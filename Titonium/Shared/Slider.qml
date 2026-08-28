pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import qs.Titonium.Theme

FocusScope {
    id: root

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
            y: control.topPadding + control.availableHeight / 2 - 2
            width: control.availableWidth
            height: 4

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.surfaceInteractive
            }

            Rectangle {
                width: control.visualPosition * parent.width
                height: parent.height
                radius: height / 2
                color: root.enabled ? Theme.accent : Theme.textDisabled
            }
        }

        handle: Rectangle {
            x: control.leftPadding + control.visualPosition
                * (control.availableWidth - width)
            y: control.topPadding + control.availableHeight / 2 - height / 2
            width: 18
            height: 18
            radius: width / 2
            color: root.enabled ? Theme.textPrimary : Theme.textDisabled
            border.width: control.activeFocus ? Metrics.borderWidth : 0
            border.color: Theme.focus
        }
    }

}
