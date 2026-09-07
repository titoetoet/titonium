pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import qs.Titonium.Theme

FocusScope {
    id: root
    property var tokens: Theme.tokens
    readonly property bool legacyPaint: tokens.legacy !== false

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
            const item = index >= 0 && index < root.model.length ? root.model[index] : null;
            root.selected(index, item?.value);
        }

        contentItem: TextLabel {
            text: root.displayText
            variant: "label"
            color: root.enabled ? root.tokens.colors.textPrimary : root.tokens.colors.textDisabled
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

        background: Item {
          Rectangle {
            anchors.fill: parent
            visible: root.legacyPaint
            radius: Metrics.radiusMedium
            color: control.down ? root.tokens.colors.surfaceInteractive : root.tokens.colors.surfaceElevated
            border.width: Metrics.borderWidth
            border.color: control.activeFocus ? root.tokens.colors.focus : root.tokens.colors.border
            Behavior on color { ColorAnimation { duration: Motion.fast } }
          }
          StylePaint {
            anchors.fill: parent
            visible: !root.legacyPaint
            tokens: root.tokens
            role: "field"
            radius: root.tokens.design.controlRadius < 0 ? 10 : root.tokens.design.controlRadius
            interaction: ({enabled:root.enabled,pressed:control.down,hovered:control.hovered,focused:control.activeFocus})
          }
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
                color: option.highlighted ? root.tokens.colors.surfaceInteractive : root.tokens.colors.surface
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

            background: Item {
                Rectangle {
                    objectName: "legacySelectPopupPaint"
                    anchors.fill: parent
                    visible: root.legacyPaint
                    color: root.tokens.colors.surface
                    radius: Metrics.radiusMedium
                    border.width: Metrics.borderWidth
                    border.color: root.tokens.colors.borderStrong
                }
                Surface {
                    anchors.fill: parent
                    visible: !root.legacyPaint
                    tokens: root.tokens
                    radius: root.tokens.design.panelRadius
                    borderColor: root.tokens.colors.borderStrong
                }
            }
        }
    }

    Accessible.role: Accessible.ComboBox
    Accessible.name: root.accessibleName
    Accessible.focusable: root.enabled
}
