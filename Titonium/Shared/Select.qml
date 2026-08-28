pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import qs.Titonium.Theme

FocusScope {
    id: root

    property var model: []
    property int currentIndex: -1
    property string accessibleName: ""
    signal selected(int index, var value)

    readonly property string displayText: {
        const item = root.currentIndex >= 0 && root.currentIndex < root.model.length
            ? root.model[root.currentIndex] : null;
        return String(item?.label || "");
    }

    implicitWidth: 180
    implicitHeight: Metrics.controlHeight
    activeFocusOnTab: root.enabled

    QtControls.ComboBox {
        id: control

        anchors.fill: parent
        model: root.model
        currentIndex: root.currentIndex
        textRole: "label"
        valueRole: "value"
        enabled: root.enabled
        activeFocusOnTab: true
        leftPadding: Metrics.spacingMedium
        rightPadding: Metrics.controlHeight

        onActivated: index => {
            root.currentIndex = index;
            const item = index >= 0 && index < root.model.length ? root.model[index] : null;
            root.selected(index, item?.value);
        }

        contentItem: TextLabel {
            text: root.displayText
            variant: "label"
            tone: root.enabled ? "primary" : "disabled"
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Icon {
            x: control.width - width - Metrics.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            name: "expand_more"
            size: 20
            tone: root.enabled ? "secondary" : "disabled"
        }

        background: Rectangle {
            radius: Metrics.radiusMedium
            color: control.down ? Theme.surfaceInteractive : Theme.surfaceElevated
            border.width: Metrics.borderWidth
            border.color: control.activeFocus ? Theme.focus : Theme.border
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        delegate: QtControls.ItemDelegate {
            id: option
            required property int index
            required property var modelData

            width: control.width
            implicitHeight: Metrics.controlHeight
            highlighted: control.highlightedIndex === index

            contentItem: TextLabel {
                text: String(option.modelData?.label || "")
                variant: "label"
                tone: option.enabled ? "primary" : "disabled"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                color: option.highlighted ? Theme.surfaceInteractive : Theme.surface
                radius: Metrics.radiusSmall
            }
        }

        popup: QtControls.Popup {
            y: control.height + Metrics.spacingXSmall
            width: control.width
            implicitHeight: Math.min(contentItem.implicitHeight + padding * 2, 240)
            padding: Metrics.spacingXSmall

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: control.popup.visible ? control.delegateModel : null
                currentIndex: control.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
            }

            background: Rectangle {
                color: Theme.surface
                radius: Metrics.radiusMedium
                border.width: Metrics.borderWidth
                border.color: Theme.borderStrong
            }
        }
    }

    Accessible.role: Accessible.ComboBox
    Accessible.name: root.accessibleName
    Accessible.focusable: root.enabled
}
