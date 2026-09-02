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
    height: implicitHeight
    Layout.preferredHeight: implicitHeight



    function triggerPrimary(): void {
        Logger.info("bluetooth", "device row clicked: " + root.device?.address
            + " actionable=" + root.actionable + " paired=" + root.device?.paired);
        if (!root.actionable)
            return;
        if (root.device.pairing)
            BluetoothService.cancelPair(root.device.address);
        else if (root.device.paired)
            BluetoothService.connectDevice(root.device.address);
        else
            BluetoothService.pairDevice(root.device.address);
    }

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusSmall
        color: (root.hovered || root.activeFocus) && root.actionable
            ? Theme.surfaceInteractive : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
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
            visible: root.device?.paired === true || root.device?.bonded === true
            iconName: "delete"
            iconColor: Theme.danger
            variant: "quiet"
            size: "small"
            accessibleName: I18n.tr("bluetooth.forget.accessible", {
                "name": root.device?.name || ""
            })
            onTriggered: BluetoothService.forgetDevice(root.device.address)
        }

        Shared.Toggle {
            visible: root.device?.connected === true
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
            visible: root.device?.connected !== true
            iconName: root.primaryActionIcon
            iconSpinning: root.device?.pairing === true || root.transitioning
            variant: "quiet"
            size: "small"
            enabled: root.actionable || root.device?.pairing === true
            accessibleName: I18n.tr("bluetooth.device.action.accessible", {
                "action": I18n.tr(root.primaryActionKey),
                "name": root.device?.name || ""
            })
            onTriggered: root.triggerPrimary()
        }

    }

    HoverHandler {
        id: rowHover
        cursorShape: root.actionable && root.device?.connected !== true
            ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.actionable && root.device?.connected !== true
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.triggerPrimary();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter) {
            root.triggerPrimary();
            event.accepted = true;
        }
    }
}
