pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root

    required property string actionId
    property bool busy: false
    property string failureMessage: ""
    signal cancelled()
    signal confirmed(string actionId)

    readonly property string actionLabel: I18n.tr("arch_menu.item." + root.actionId)

    implicitWidth: 276
    implicitHeight: content.implicitHeight
    enabled: !root.busy

    ColumnLayout {
        id: content
        width: parent.width
        spacing: Metrics.spacingMedium

        Controls.Icon {
            Layout.alignment: Qt.AlignHCenter
            name: "warning"
            size: 28
            tone: root.actionId === "restart" || root.actionId === "shutdown"
                ? "danger" : "warning"
            accessibleName: ""
        }

        Controls.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("arch_menu.confirm.title", { "action": root.actionLabel })
            variant: "title_small"
            strong: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Controls.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("arch_menu.confirm.consequence." + root.actionId)
            variant: "body"
            tone: "secondary"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Controls.TextLabel {
            Layout.fillWidth: true
            visible: root.failureMessage.length > 0
            text: root.failureMessage
            variant: "caption"
            tone: "danger"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSmall

            Controls.Button {
                id: cancelButton
                Layout.fillWidth: true
                label: I18n.tr("arch_menu.confirm.cancel")
                variant: "secondary"
                enabled: !root.busy
                activeFocusOnTab: enabled
                accessibleName: label
                Accessible.role: Accessible.Button
                onTriggered: root.cancelled()
            }

            Controls.Button {
                id: confirmButton
                Layout.fillWidth: true
                label: I18n.tr("arch_menu.confirm.action." + root.actionId)
                variant: root.actionId === "restart" || root.actionId === "shutdown"
                    ? "danger" : "primary"
                enabled: !root.busy
                activeFocusOnTab: enabled
                accessibleName: label
                Accessible.role: Accessible.Button
                onTriggered: root.confirmed(root.actionId)
            }
        }
    }

    Component.onCompleted: cancelButton.forceActiveFocus(Qt.PopupFocusReason)
}
