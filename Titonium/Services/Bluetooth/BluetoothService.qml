pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.Titonium.Core.Runtime
import "BluetoothRules.js" as BluetoothRules

QtObject {
    id: root

    readonly property var projection: {
        const bluetooth = Bluetooth;
        const adapter = bluetooth.defaultAdapter;
        if (adapter === null || adapter === undefined)
            return BluetoothRules.projectAdapter(null);

        const source = adapter.devices.values || [];
        return BluetoothRules.projectAdapter({
            name: adapter.name,
            enabled: adapter.enabled === true,
            discovering: adapter.discovering === true,
            devices: source.map(device => ({
                address: device?.address,
                name: device?.name || device?.deviceName,
                icon: device?.icon,
                connected: device?.connected === true,
                paired: device?.paired === true,
                pairing: device?.pairing === true,
                blocked: device?.blocked === true,
                batteryAvailable: device?.batteryAvailable === true,
                battery: device?.battery,
                connecting: device?.state === BluetoothDeviceState.Connecting,
                disconnecting: device?.state === BluetoothDeviceState.Disconnecting,
            })),
        });
    }
    readonly property bool available: root.projection.available
    readonly property bool powered: root.projection.powered
    readonly property bool discovering: root.projection.discovering
    readonly property string adapterName: root.projection.adapterName
    readonly property int connectedCount: root.projection.connectedCount
    readonly property var devices: root.projection.devices
    readonly property string stateKey: root.projection.stateKey
    readonly property int operationWarningLimit: 3

    property int operationWarningCount: 0

    function warnOperation(message: string): void {
        if (root.operationWarningCount >= root.operationWarningLimit)
            return;
        root.operationWarningCount += 1;
        Logger.warn("bluetooth", message);
    }

    function setPowered(value: bool): bool {
        if (typeof value !== "boolean") {
            root.warnOperation("ignored invalid power request");
            return false;
        }

        const bluetooth = Bluetooth;
        const adapter = bluetooth.defaultAdapter;
        if (adapter === null || adapter === undefined) {
            root.warnOperation("ignored power request without adapter");
            return false;
        }

        try {
            if (!value && adapter.discovering === true)
                adapter.discovering = false;
            adapter.enabled = value;
            return true;
        } catch (error) {
            root.warnOperation("power request failed");
            return false;
        }
    }

    function setDiscovering(value: bool): bool {
        if (typeof value !== "boolean") {
            root.warnOperation("ignored invalid discovery request");
            return false;
        }

        const bluetooth = Bluetooth;
        const adapter = bluetooth.defaultAdapter;
        if (adapter === null || adapter === undefined || adapter.enabled !== true) {
            root.warnOperation("ignored discovery request without powered adapter");
            return false;
        }

        try {
            adapter.discovering = value;
            return true;
        } catch (error) {
            root.warnOperation("discovery request failed");
            return false;
        }
    }

    function connectDevice(address: string): bool {
        const nativeDeviceForAddress = function(requestedAddress) {
            const bluetooth = Bluetooth;
            const adapter = bluetooth.defaultAdapter;
            const normalizedAddress = BluetoothRules.normalizedAddress(requestedAddress).toLowerCase();
            if (adapter === null || adapter === undefined || normalizedAddress.length === 0)
                return null;
            const source = adapter.devices.values || [];
            for (let index = 0; index < source.length; index += 1) {
                const candidate = source[index];
                if (BluetoothRules.normalizedAddress(candidate?.address).toLowerCase()
                        === normalizedAddress)
                    return candidate;
            }
            return null;
        };
        const device = nativeDeviceForAddress(address);
        if (device === null) {
            root.warnOperation("ignored connect request for stale device");
            return false;
        }

        try {
            device.connect();
            return true;
        } catch (error) {
            root.warnOperation("connect request failed");
            return false;
        }
    }

    function disconnectDevice(address: string): bool {
        const nativeDeviceForAddress = function(requestedAddress) {
            const bluetooth = Bluetooth;
            const adapter = bluetooth.defaultAdapter;
            const normalizedAddress = BluetoothRules.normalizedAddress(requestedAddress).toLowerCase();
            if (adapter === null || adapter === undefined || normalizedAddress.length === 0)
                return null;
            const source = adapter.devices.values || [];
            for (let index = 0; index < source.length; index += 1) {
                const candidate = source[index];
                if (BluetoothRules.normalizedAddress(candidate?.address).toLowerCase()
                        === normalizedAddress)
                    return candidate;
            }
            return null;
        };
        const device = nativeDeviceForAddress(address);
        if (device === null) {
            root.warnOperation("ignored disconnect request for stale device");
            return false;
        }

        try {
            device.disconnect();
            return true;
        } catch (error) {
            root.warnOperation("disconnect request failed");
            return false;
        }
    }

    function pairDevice(address: string): bool {
        const nativeDeviceForAddress = function(requestedAddress) {
            const bluetooth = Bluetooth;
            const adapter = bluetooth.defaultAdapter;
            const normalizedAddress = BluetoothRules.normalizedAddress(requestedAddress).toLowerCase();
            if (adapter === null || adapter === undefined || normalizedAddress.length === 0)
                return null;
            const source = adapter.devices.values || [];
            for (let index = 0; index < source.length; index += 1) {
                const candidate = source[index];
                if (BluetoothRules.normalizedAddress(candidate?.address).toLowerCase()
                        === normalizedAddress)
                    return candidate;
            }
            return null;
        };
        const device = nativeDeviceForAddress(address);
        if (device === null) {
            root.warnOperation("ignored pair request for stale device");
            return false;
        }

        try {
            device.pair();
            return true;
        } catch (error) {
            root.warnOperation("pair request failed");
            return false;
        }
    }

    function cancelPair(address: string): bool {
        const nativeDeviceForAddress = function(requestedAddress) {
            const bluetooth = Bluetooth;
            const adapter = bluetooth.defaultAdapter;
            const normalizedAddress = BluetoothRules.normalizedAddress(requestedAddress).toLowerCase();
            if (adapter === null || adapter === undefined || normalizedAddress.length === 0)
                return null;
            const source = adapter.devices.values || [];
            for (let index = 0; index < source.length; index += 1) {
                const candidate = source[index];
                if (BluetoothRules.normalizedAddress(candidate?.address).toLowerCase()
                        === normalizedAddress)
                    return candidate;
            }
            return null;
        };
        const device = nativeDeviceForAddress(address);
        if (device === null) {
            root.warnOperation("ignored pair cancellation for stale device");
            return false;
        }

        try {
            device.cancelPair();
            return true;
        } catch (error) {
            root.warnOperation("pair cancellation failed");
            return false;
        }
    }

    function forgetDevice(address: string): bool {
        const nativeDeviceForAddress = function(requestedAddress) {
            const bluetooth = Bluetooth;
            const adapter = bluetooth.defaultAdapter;
            const normalizedAddress = BluetoothRules.normalizedAddress(requestedAddress).toLowerCase();
            if (adapter === null || adapter === undefined || normalizedAddress.length === 0)
                return null;
            const source = adapter.devices.values || [];
            for (let index = 0; index < source.length; index += 1) {
                const candidate = source[index];
                if (BluetoothRules.normalizedAddress(candidate?.address).toLowerCase()
                        === normalizedAddress)
                    return candidate;
            }
            return null;
        };
        const device = nativeDeviceForAddress(address);
        if (device === null) {
            root.warnOperation("ignored forget request for stale device");
            return false;
        }

        try {
            device.forget();
            return true;
        } catch (error) {
            root.warnOperation("forget request failed");
            return false;
        }
    }

    function snapshot(): string {
        return JSON.stringify({
            available: root.available,
            powered: root.powered,
            discovering: root.discovering,
            adapterName: root.adapterName,
            connectedCount: root.connectedCount,
            devices: root.devices,
            stateKey: root.stateKey,
        });
    }
}
