pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Overlays.Audio
import qs.Titonium.Overlays.Bluetooth
import qs.Titonium.Services.Audio
import qs.Titonium.Services.Bluetooth
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root
    required property var screen
    property bool showDiagnostics: true
    readonly property int diagnosticsWidth: networkIcon.implicitWidth + bluetoothButton.implicitWidth
        + Metrics.spacingSmall
    readonly property int audioWidth: audioButton.implicitWidth
    readonly property int fullImplicitWidth: root.diagnosticsWidth + Metrics.spacingSmall + root.audioWidth
    readonly property string outputAccessibleName: AudioService.outputAvailable
        ? AudioService.outputName : I18n.tr("audio.output")
    readonly property string audioAccessibleName: !AudioService.outputAvailable
        ? I18n.tr("audio.output.accessible.unavailable", { "name": root.outputAccessibleName })
        : (AudioService.outputMuted
            ? I18n.tr("audio.output.accessible.muted", { "name": root.outputAccessibleName })
            : I18n.tr("audio.output.accessible.volume", {
                "name": root.outputAccessibleName,
                "percentage": Math.round(AudioService.outputVolume * 100)
            }))
    readonly property string bluetoothAccessibleName: I18n.tr(
        "menubar.connectivity.bluetooth.accessible", {
            "state": I18n.tr(BluetoothService.stateKey),
            "count": BluetoothService.connectedCount
        })
    readonly property string bluetoothIconName: !BluetoothService.available || !BluetoothService.powered
        ? "bluetooth_disabled" : (BluetoothService.discovering ? "bluetooth_searching"
            : (BluetoothService.connectedCount > 0 ? "bluetooth_connected" : "bluetooth"))
    readonly property string bluetoothTone: !BluetoothService.available || !BluetoothService.powered
        ? "disabled" : (BluetoothService.discovering ? "accent"
            : (BluetoothService.connectedCount > 0 ? "success" : "secondary"))

    implicitWidth: root.audioWidth + (root.showDiagnostics
        ? root.diagnosticsWidth + Metrics.spacingSmall : 0)
    implicitHeight: Metrics.widgetHeight

    Shared.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusSmall
    }

    Row {
        id: iconRow
        anchors.centerIn: parent
        spacing: Metrics.spacingSmall

        Shared.Icon {
            id: networkIcon
            visible: root.showDiagnostics
            name: "wifi"
            size: 18
            tone: "secondary"
            accessibleName: I18n.tr("menubar.connectivity.network_planned")
        }
        Shared.Button {
            id: bluetoothButton
            visible: root.showDiagnostics
            variant: "quiet"
            size: "small"
            accessibleName: root.bluetoothAccessibleName
            onTriggered: BluetoothPopupCoordinator.toggle(root.screen)
        }
        Shared.Icon {
            anchors.centerIn: bluetoothButton
            visible: bluetoothButton.visible
            name: root.bluetoothIconName
            size: 18
            tone: root.bluetoothTone
            accessibleName: ""
        }
        Shared.Button {
            id: audioButton
            iconName: AudioService.outputIcon
            variant: "quiet"
            size: "small"
            accessibleName: root.audioAccessibleName
            onTriggered: AudioPopupCoordinator.toggle(root.screen)

            WheelHandler {
                onWheel: event => {
                    if (event.angleDelta.y === 0)
                        return;
                    AudioService.adjustOutputVolume(event.angleDelta.y > 0 ? 0.05 : -0.05);
                    event.accepted = true;
                }
            }
        }
    }
}
