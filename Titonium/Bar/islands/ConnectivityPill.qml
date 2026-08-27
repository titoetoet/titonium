pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Overlays.Audio
import qs.Titonium.Overlays.Bluetooth
import qs.Titonium.Overlays.Network
import qs.Titonium.Services.Audio
import qs.Titonium.Services.Bluetooth
import qs.Titonium.Services.Network
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root
    required property var screen
    property bool showDiagnostics: true
    readonly property int controlSize: Metrics.controlHeightSmall
    readonly property int diagnosticsWidth: networkButton.implicitWidth + bluetoothButton.implicitWidth
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
            "state": I18n.tr(BluetoothService.stateKey, {
                "count": BluetoothService.connectedCount
            }),
            "count": BluetoothService.connectedCount
        })
    readonly property string bluetoothIconName: !BluetoothService.available || !BluetoothService.powered
        ? "bluetooth_disabled" : (BluetoothService.discovering ? "bluetooth_searching"
            : (BluetoothService.connectedCount > 0 ? "bluetooth_connected" : "bluetooth"))
    readonly property string networkAccessibleName: I18n.tr(NetworkService.stateKey, {
        "name": NetworkService.connectedName
    })
    readonly property string networkIconName: !NetworkService.available || !NetworkService.wifiHardwareEnabled
        ? "wifi_off" : (NetworkService.wifiEnabled ? "wifi" : "wifi_off")

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

        Shared.Button {
            id: networkButton
            visible: root.showDiagnostics
            width: root.controlSize
            height: root.controlSize
            iconName: root.networkIconName
            variant: "quiet"
            size: "small"
            enabled: NetworkService.available
            accessibleName: root.networkAccessibleName
            onTriggered: NetworkPopupCoordinator.toggle(root.screen, networkButton)
        }
        Shared.Button {
            id: bluetoothButton
            visible: root.showDiagnostics
            width: root.controlSize
            height: root.controlSize
            iconName: root.bluetoothIconName
            variant: "quiet"
            size: "small"
            accessibleName: root.bluetoothAccessibleName
            onTriggered: BluetoothPopupCoordinator.toggle(root.screen, bluetoothButton)
        }
        Shared.Button {
            id: audioButton
            width: root.controlSize
            height: root.controlSize
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
