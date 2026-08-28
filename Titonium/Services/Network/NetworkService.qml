pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Networking
import qs.Titonium.Core.Runtime
import "WifiRules.js" as WifiRules

QtObject {
    id: root

    readonly property var projection: {
        const source = Networking.devices.values || [];
        const wifiDevices = source.filter(device => device?.type === DeviceType.Wifi);
        if (wifiDevices.length === 0)
            return WifiRules.projectWifi(null);

        const networks = [];
        let scanning = false;
        wifiDevices.forEach(device => {
            scanning = scanning || device.scannerEnabled === true;
            const deviceNetworks = device.networks.values || [];
            deviceNetworks.forEach(network => networks.push({
                name: network?.name,
                connected: network?.connected === true,
                known: network?.known === true,
                state: network?.state === ConnectionState.Connecting ? "connecting"
                    : (network?.state === ConnectionState.Disconnecting ? "disconnecting" : ""),
                signal: network?.signalStrength,
                secure: network?.security !== WifiSecurityType.Open,
            }));
        });
        return WifiRules.projectWifi({
            wifiEnabled: Networking.wifiEnabled === true,
            wifiHardwareEnabled: Networking.wifiHardwareEnabled === true,
            scanning: scanning,
            devices: networks,
        });
    }
    readonly property bool available: root.projection.available
    readonly property bool wifiEnabled: root.projection.wifiEnabled
    readonly property bool wifiHardwareEnabled: root.projection.wifiHardwareEnabled
    readonly property bool scanning: root.projection.scanning
    readonly property string connectedName: root.projection.connectedName
    readonly property int connectedSignal: root.projection.connectedSignal
    readonly property string iconName: root.projection.iconName
    readonly property var networks: root.projection.networks
    readonly property string stateKey: root.projection.stateKey
    readonly property int operationWarningLimit: 3

    property var operationWarningCounts: ({})

    function warnOperation(category: string, message: string): void {
        const count = root.operationWarningCounts[category] || 0;
        if (count >= root.operationWarningLimit)
            return;
        root.operationWarningCounts[category] = count + 1;
        Logger.warn("network", message);
    }

    function setWifiEnabled(value: bool): bool {
        if (typeof value !== "boolean") {
            root.warnOperation("wifi.invalid", "ignored invalid Wi-Fi request");
            return false;
        }
        try {
            if (!value)
                root.setScanning(false);
            Networking.wifiEnabled = value;
            return true;
        } catch (error) {
            root.warnOperation("wifi.failure", "Wi-Fi request failed");
            return false;
        }
    }

    function setScanning(value: bool): bool {
        if (typeof value !== "boolean") {
            root.warnOperation("scan.invalid", "ignored invalid scan request");
            return false;
        }
        const source = Networking.devices.values || [];
        const wifiDevices = source.filter(device => device?.type === DeviceType.Wifi);
        if (wifiDevices.length === 0 || Networking.wifiEnabled !== true) {
            root.warnOperation("scan.unavailable", "ignored scan request without Wi-Fi");
            return false;
        }
        try {
            wifiDevices.forEach(device => device.scannerEnabled = value);
            return true;
        } catch (error) {
            root.warnOperation("scan.failure", "Wi-Fi scan request failed");
            return false;
        }
    }

    function connect(id: string): bool {
        const nativeNetworkForId = function(requestedId) {
            const source = Networking.devices.values || [];
            const candidates = [];
            for (let deviceIndex = 0; deviceIndex < source.length; deviceIndex += 1) {
                const device = source[deviceIndex];
                if (device?.type !== DeviceType.Wifi)
                    continue;
                const networks = device.networks.values || [];
                for (let networkIndex = 0; networkIndex < networks.length; networkIndex += 1) {
                    const candidate = networks[networkIndex];
                    candidates.push({
                        native: candidate,
                        name: candidate?.name,
                        connected: candidate?.connected === true,
                        known: candidate?.known === true,
                        signal: candidate?.signalStrength,
                    });
                }
            }
            return WifiRules.preferredNativeForId(candidates, requestedId);
        };
        const network = nativeNetworkForId(id);
        if (network === null) {
            root.warnOperation("connect.stale", "ignored connect request for stale Wi-Fi network");
            return false;
        }
        try {
            network.connect();
            return true;
        } catch (error) {
            root.warnOperation("connect.failure", "Wi-Fi connect request failed");
            return false;
        }
    }

    function connectWithPassword(id: string, password: string): bool {
        const nativeNetworkForId = function(requestedId) {
            const source = Networking.devices.values || [];
            const candidates = [];
            for (let deviceIndex = 0; deviceIndex < source.length; deviceIndex += 1) {
                const device = source[deviceIndex];
                if (device?.type !== DeviceType.Wifi)
                    continue;
                const networks = device.networks.values || [];
                for (let networkIndex = 0; networkIndex < networks.length; networkIndex += 1) {
                    const candidate = networks[networkIndex];
                    candidates.push({
                        native: candidate,
                        name: candidate?.name,
                        connected: candidate?.connected === true,
                        known: candidate?.known === true,
                        signal: candidate?.signalStrength,
                    });
                }
            }
            return WifiRules.preferredNativeForId(candidates, requestedId);
        };
        if (typeof password !== "string" || password.length === 0) {
            root.warnOperation("connect.password", "ignored empty Wi-Fi password");
            return false;
        }
        const network = nativeNetworkForId(id);
        if (network === null) {
            root.warnOperation("connect.password.stale", "ignored connect request for stale Wi-Fi network");
            return false;
        }
        try {
            network.connectWithPsk(password);
            return true;
        } catch (error) {
            root.warnOperation("connect.password.failure", "Wi-Fi password connect request failed");
            return false;
        }
    }

    function disconnect(id: string): bool {
        const nativeNetworkForId = function(requestedId) {
            const source = Networking.devices.values || [];
            const candidates = [];
            for (let deviceIndex = 0; deviceIndex < source.length; deviceIndex += 1) {
                const device = source[deviceIndex];
                if (device?.type !== DeviceType.Wifi)
                    continue;
                const networks = device.networks.values || [];
                for (let networkIndex = 0; networkIndex < networks.length; networkIndex += 1) {
                    const candidate = networks[networkIndex];
                    candidates.push({
                        native: candidate,
                        name: candidate?.name,
                        connected: candidate?.connected === true,
                        known: candidate?.known === true,
                        signal: candidate?.signalStrength,
                    });
                }
            }
            return WifiRules.preferredNativeForId(candidates, requestedId);
        };
        const network = nativeNetworkForId(id);
        if (network === null) {
            root.warnOperation("disconnect.stale", "ignored disconnect request for stale Wi-Fi network");
            return false;
        }
        try {
            network.disconnect();
            return true;
        } catch (error) {
            root.warnOperation("disconnect.failure", "Wi-Fi disconnect request failed");
            return false;
        }
    }

    function forget(id: string): bool {
        const nativeNetworkForId = function(requestedId) {
            const source = Networking.devices.values || [];
            const candidates = [];
            for (let deviceIndex = 0; deviceIndex < source.length; deviceIndex += 1) {
                const device = source[deviceIndex];
                if (device?.type !== DeviceType.Wifi)
                    continue;
                const networks = device.networks.values || [];
                for (let networkIndex = 0; networkIndex < networks.length; networkIndex += 1) {
                    const candidate = networks[networkIndex];
                    candidates.push({
                        native: candidate,
                        name: candidate?.name,
                        connected: candidate?.connected === true,
                        known: candidate?.known === true,
                        signal: candidate?.signalStrength,
                    });
                }
            }
            return WifiRules.preferredNativeForId(candidates, requestedId);
        };
        const network = nativeNetworkForId(id);
        if (network === null) {
            root.warnOperation("forget.stale", "ignored forget request for stale Wi-Fi network");
            return false;
        }
        try {
            network.forget();
            return true;
        } catch (error) {
            root.warnOperation("forget.failure", "Wi-Fi forget request failed");
            return false;
        }
    }

    function snapshot(): string {
        return JSON.stringify({
            available: root.available,
            wifiEnabled: root.wifiEnabled,
            wifiHardwareEnabled: root.wifiHardwareEnabled,
            scanning: root.scanning,
            connectedName: root.connectedName,
            connectedSignal: root.connectedSignal,
            iconName: root.iconName,
            networks: root.networks,
            stateKey: root.stateKey,
        });
    }
}
