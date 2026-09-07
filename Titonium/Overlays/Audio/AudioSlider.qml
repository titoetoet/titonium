pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property real serviceValue: 0
    property real maximumValue: 1
    property bool liveUpdate: true
    property string accessibleName: ""
    signal userValueChanged(real value)

    implicitWidth: 120
    implicitHeight: Metrics.controlHeight

    function syncFromService(): void {
        if (!slider.pressed)
            slider.value = Math.max(slider.from, Math.min(slider.to, root.serviceValue));
    }

    onServiceValueChanged: root.syncFromService()
    onMaximumValueChanged: root.syncFromService()

    QtControls.Slider {
        id: slider
        anchors.fill: parent
        from: 0
        to: Math.max(0, root.maximumValue)
        stepSize: 0.01
        live: root.liveUpdate
        activeFocusOnTab: true

        onMoved: root.userValueChanged(value)
        onPressedChanged: {
            if (!pressed)
                root.syncFromService();
        }

        background: Item {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 4

            Rectangle {
                anchors.fill: parent
                visible: Theme.legacy
                radius: 2
                color: Theme.surfaceInteractive
            }

            Shared.StylePaint {
                anchors.fill: parent
                visible: !Theme.legacy
                tokens: Theme.tokens
                role: "field"
                radius: 2
                customColor: Theme.surfaceInteractive
                outlined: false
                showFocus: false
            }

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }

        handle: Item {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 14
            height: 14

            Rectangle {
                anchors.fill: parent
                visible: Theme.legacy
                radius: width / 2
                color: slider.pressed ? Theme.accent : Theme.textPrimary
                border.width: slider.activeFocus ? Metrics.borderWidth : 0
                border.color: Theme.focus
            }

            Shared.StylePaint {
                anchors.fill: parent
                visible: !Theme.legacy
                tokens: Theme.tokens
                role: "button"
                radius: width / 2
                customColor: slider.pressed ? Theme.accent : Theme.textPrimary
                interaction: ({ pressed: slider.pressed, focused: slider.activeFocus })
            }
        }

        Accessible.name: root.accessibleName
    }

    Component.onCompleted: root.syncFromService()
}
