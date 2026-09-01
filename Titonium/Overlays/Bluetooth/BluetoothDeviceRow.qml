pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Bluetooth
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    property var device: null
    property bool forgetConfirmation: false
    readonly property bool transitioning: root.device?.stateKey === "bluetooth.device.connecting"
        || root.device?.stateKey === "bluetooth.device.disconnecting"
    readonly property bool actionable: root.device !== null && root.device.blocked !== true
        && !root.transitioning
    readonly property bool hovered: rowHover.hovered
    readonly property string primaryActionKey: root.device?.pairing === true
        ? "bluetooth.device.cancel_pair" : (root.device?.paired === true
            ? "bluetooth.device.connect" : "bluetooth.device.pair")
    readonly property string primaryActionIcon: root.device?.pairing === true
        ? "close" : (root.device?.paired === true ? "link" : "bluetooth_searching")

    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth

    onDeviceChanged: root.forgetConfirmation = false

    function triggerPrimary(): void {
        if (!root.actionable)
            return;
        if (root.device.pairing)
            BluetoothService.cancelPair(root.device.address);
        else if (root.device.paired)
            BluetoothService.connectDevice(root.device.address);
        else
            BluetoothService.pairDevice(root.device.address);
    }

    RowLayout {
        id: content
        width: parent.width
        spacing: Metrics.spacingMedium

        Shared.SystemIcon {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Metrics.spacingXSmall
            sourceName: root.device?.icon || "bluetooth"
            fallbackName: "bluetooth"
            size: 22
            tone: root.actionable ? "secondary" : "disabled"
            accessibleName: ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingXSmall

            Shared.TextLabel {
                Layout.fillWidth: true
                text: root.device?.name || ""
                variant: "label"
                strong: true
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingSmall

                Shared.TextLabel {
                    text: I18n.tr(root.device?.stateKey || "bluetooth.device.available")
                    tone: root.actionable ? "secondary" : "disabled"
                    variant: "caption"
                }

                Shared.TextLabel {
                    visible: root.device?.batteryAvailable === true
                    text: I18n.tr("bluetooth.device.battery", {
                        "percentage": root.device?.battery || 0
                    })
                    tone: "secondary"
                    variant: "caption"
                }
            }
        }

        Shared.Button {
            id: deviceInfoButton
            visible: root.device?.paired === true && !root.forgetConfirmation
            opacity: root.hovered || deviceInfoButton.activeFocus ? 1 : 0
            iconName: "info"
            variant: "quiet"
            size: "small"
            accessibleName: I18n.tr("bluetooth.forget.accessible", {
                "name": root.device?.name || ""
            })
            onTriggered: root.forgetConfirmation = true
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }

        Shared.Toggle {
            visible: root.device?.connected === true && !root.forgetConfirmation
            checked: root.device?.connected === true
            enabled: root.actionable
            accessibleName: I18n.tr("bluetooth.device.action.accessible", {
                "action": I18n.tr("bluetooth.device.disconnect"),
                "name": root.device?.name || ""
            })
            onToggled: checked => {
                if (!checked && root.device?.connected === true)
                    BluetoothService.disconnectDevice(root.device.address);
            }
        }

        Shared.Button {
            Layout.alignment: Qt.AlignVCenter
            visible: root.device?.connected !== true && !root.forgetConfirmation
            iconName: root.primaryActionIcon
            variant: "quiet"
            size: "small"
            enabled: root.actionable
            accessibleName: I18n.tr("bluetooth.device.action.accessible", {
                "action": I18n.tr(root.primaryActionKey),
                "name": root.device?.name || ""
            })
            onTriggered: root.triggerPrimary()
        }

        Shared.Button {
            id: cancelForgetButton
            visible: root.device?.paired === true && root.forgetConfirmation
            iconName: "close"
            variant: "quiet"
            size: "small"
            accessibleName: I18n.tr("bluetooth.forget.cancel")
            onTriggered: root.forgetConfirmation = false
        }

        Shared.Button {
            id: confirmForgetButton
            visible: root.device?.paired === true && root.forgetConfirmation
            iconName: "delete"
            variant: "danger"
            size: "small"
            accessibleName: I18n.tr("bluetooth.forget.accessible", {
                "name": root.device?.name || ""
            })
            onTriggered: {
                BluetoothService.forgetDevice(root.device.address);
                root.forgetConfirmation = false;
            }
        }
    }

    HoverHandler { id: rowHover }
}
