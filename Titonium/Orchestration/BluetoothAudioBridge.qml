pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Audio
import qs.Titonium.Services.Bluetooth

QtObject {
    property Connections bluetoothConnection: Connections {
        target: BluetoothService

        function onAudioDeviceConnected(address: string): void {
            AudioService.requestBluetoothOutput(address);
        }
    }

    property Connections audioConnection: Connections {
        target: AudioService

        function onBluetoothOutputSelected(address: string): void {
            BluetoothService.completeAudioConnection(address);
        }
    }
}
