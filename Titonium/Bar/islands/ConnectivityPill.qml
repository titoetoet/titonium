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
    readonly property int controlSize: 28
    readonly property int innerPadding: 2
    readonly property int diagnosticsWidth: networkButton.width + bluetoothButton.width
    readonly property int audioWidth: audioButton.implicitWidth
    readonly property int fullImplicitWidth: root.audioWidth + root.innerPadding * 2
        + (root.showDiagnostics
            ? root.diagnosticsWidth + Metrics.spacingXSmall * 2 : 0)
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
    readonly property color bluetoothIconColor: BluetoothService.connectedCount > 0 ? Theme.accent
        : (bluetoothButton.enabled ? Theme.textPrimary : Theme.textDisabled)
    readonly property string networkAccessibleName: I18n.tr(NetworkService.stateKey, {
        "name": NetworkService.connectedName
    })

    implicitWidth: root.fullImplicitWidth
    implicitHeight: Metrics.widgetHeight

    function anchorRect(name: string): rect {
        const item = name === "network" ? networkButton
            : (name === "bluetooth" ? bluetoothButton : (name === "audio" ? audioButton : null));
        return item ? Qt.rect(iconRow.x + item.x, iconRow.y + item.y, item.width, item.height)
            : Qt.rect(0, 0, 0, 0);
    }

    Row {
        id: iconRow
        anchors.centerIn: parent
        spacing: Metrics.spacingXSmall

        Shared.Button {
            id: networkButton
            visible: root.showDiagnostics
            width: root.controlSize
            height: root.controlSize
            iconName: NetworkService.iconName
            iconHoverMotion: true
            variant: "quiet"
            size: "small"
            showFocusRing: false
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
            iconHoverMotion: true
            iconColor: root.bluetoothIconColor
            variant: "quiet"
            size: "small"
            showFocusRing: false
            accessibleName: root.bluetoothAccessibleName
            onTriggered: BluetoothPopupCoordinator.toggle(root.screen, bluetoothButton)
        }
        Shared.Button {
            id: audioButton
            width: root.controlSize
            height: root.controlSize
            iconName: AudioService.outputIcon
            iconHoverMotion: true
            variant: "quiet"
            size: "small"
            showFocusRing: false
            accessibleName: root.audioAccessibleName
            onTriggered: AudioPopupCoordinator.toggle(root.screen, audioButton)

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
