pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center
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
                bonded: device?.bonded === true,
                pairing: device?.pairing === true
                    || (BluetoothRules.normalizedAddress(device?.address).toLowerCase()
                            === root.pendingPairAddress.toLowerCase()
                        && device?.paired !== true && device?.connected !== true),
                trusted: device?.trusted === true,
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

    property var operationWarningCounts: ({})
    property var previousConnectedAudioAddresses: null
    property string pendingPairAddress: ""
    property bool pairingWasActive: false
    property bool connectAttempted: false
    property int agentAttempts: 0
    readonly property int agentAttemptLimit: 6

    signal audioDeviceConnected(string address)

    // Persistent BlueZ pairing agent. Native device.pair() only initiates the
    // pairing request; a registered agent is what completes it on this
    // agent-less (bare Hyprland) system. The process stays alive while its
    // stdin pipe is open. Crashes get five delayed retries; a stable run,
    // adapter change, or an explicit pairing request restores the retry budget.
    property Process agentProcess: Process {
        command: ["bluetoothctl", "--agent", "NoInputNoOutput"]
        stdinEnabled: true
        stdout: StdioCollector { waitForEnd: false }
        stderr: StdioCollector { waitForEnd: false }
        onStarted: root.agentStable.restart()
        onExited: exitCode => {
            root.agentStable.stop();
            if (!root.available)
                return;
            root.warnOperation("agent.exit", "agent process exited: " + exitCode);
            if (root.agentAttempts >= root.agentAttemptLimit) {
                root.warnOperation("agent.exhausted", "pairing agent retries exhausted");
                return;
            }
            root.agentRetry.interval = Math.min(16000,
                1000 * Math.pow(2, Math.max(0, root.agentAttempts - 1)));
            root.agentRetry.restart();
        }
    }

    property Timer agentRetry: Timer {
        repeat: false
        onTriggered: root.ensureAgent()
    }

    property Timer agentStable: Timer {
        interval: 30000
        repeat: false
        onTriggered: {
            if (root.agentProcess.running)
                root.agentAttempts = 1;
        }
    }

    property Connections agentAdapterConnections: Connections {
        target: Bluetooth
        function onDefaultAdapterChanged(): void {
            root.resetAgentRetry();
            root.ensureAgent();
        }
    }

    property Timer pairWatchdog: Timer {
        interval: 30000
        repeat: false
        onTriggered: {
            if (!root.pendingPairAddress)
                return;
            const device = root.nativeDeviceForAddress(root.pendingPairAddress);
            if (device !== null && device.pairing === true)
                device.cancelPair();
            root.failPair("pair.timeout", "pairing timed out");
        }
    }

    property Timer connectWatchdog: Timer {
        interval: 15000
        repeat: false
        onTriggered: {
            if (!root.pendingPairAddress)
                return;
            root.failPair("connect.timeout", "connection timed out");
        }
    }

    function resetAgentRetry(): void {
        root.agentRetry.stop();
        root.agentStable.stop();
        root.agentAttempts = root.agentProcess.running ? 1 : 0;
        if (root.available && root.agentProcess.running)
            root.agentStable.restart();
    }

    function ensureAgent(): void {
        if (!root.available || root.agentProcess.running || root.agentRetry.running
                || root.agentAttempts >= root.agentAttemptLimit)
            return;
        root.agentAttempts += 1;
        Logger.info("bluetooth", "starting pairing agent");
        root.agentProcess.running = true;
    }

    function nativeDeviceForAddress(requestedAddress: string): var {
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
    }

    function resetPairing(): void {
        root.pendingPairAddress = "";
        root.pairingWasActive = false;
        root.connectAttempted = false;
        root.pairWatchdog.stop();
        root.connectWatchdog.stop();
    }

    function failPair(reason: string, message: string): void {
        root.resetPairing();
        root.warnOperation(reason, message);
        CenterAttentionService.publish({
            id: "bluetooth:pair", source: "bluetooth", kind: "pair_failed",
            title: I18n.tr("bluetooth.center.pair_failed"), icon: "bluetooth_disabled"
        });
    }

    // Drives the pair -> auto-connect chain purely from native reactive state.
    // Runs on every projection change; each branch is idempotent so repeated
    // invocations never issue duplicate native calls.
    function observePairProgress(): void {
        const address = root.pendingPairAddress;
        if (!address)
            return;
        const device = root.nativeDeviceForAddress(address);
        if (device === null) {
            // Device disappeared (forgotten) — reset without surfacing an error.
            root.resetPairing();
            return;
        }
        if (device.connected === true) {
            root.resetPairing();
            return;
        }
        if (device.pairing === true) {
            root.pairingWasActive = true;
            return;
        }
        if (device.paired === true) {
            if (!root.connectAttempted && device.state !== BluetoothDeviceState.Connecting) {
                Logger.info("bluetooth", "paired, auto-connecting " + address);
                root.connectAttempted = true;
                if (device.trusted !== true)
                    device.trusted = true;
                device.connect();
                root.connectWatchdog.restart();
            }
            return;
        }
        if (device.state === BluetoothDeviceState.Connecting)
            return;
        // Pairing finished (native pairing flag went active then inactive) without
        // the device becoming paired. If pair() was just issued, native pairing
        // has not propagated yet and we wait for the watchdog instead.
        if (root.pairingWasActive)
            root.failPair("pair.failed", "pairing failed for " + address);
    }

    function observeAudioConnections(): void {
        const event = BluetoothRules.audioConnectionEvent(
            root.previousConnectedAudioAddresses, root.devices);
        const baselineReady = root.previousConnectedAudioAddresses !== null;
        root.previousConnectedAudioAddresses = event.current;
        if (!baselineReady)
            return;
        for (let index = 0; index < event.connected.length; index += 1) {
            Logger.info("bluetooth", "audio device connected " + event.connected[index]);
            root.audioDeviceConnected(event.connected[index]);
            CenterAttentionService.publish({
                id: "bluetooth:audio", source: "bluetooth", kind: "device_connected",
                title: I18n.tr("bluetooth.center.connected"), icon: "headphones"
            });
        }
        for (let index = 0; index < event.disconnected.length; index += 1) {
            Logger.info("bluetooth", "audio device disconnected " + event.disconnected[index]);
            CenterAttentionService.publish({
                id: "bluetooth:audio", source: "bluetooth", kind: "device_disconnected",
                title: I18n.tr("bluetooth.center.disconnected"), icon: "headphones"
            });
        }
        CenterAttentionService.setIndicator(
            "bluetooth-headphone", "headphones", I18n.tr("bluetooth.center.headphone"),
            event.current.length > 0);
    }

    function warnOperation(category: string, message: string): void {
        const count = root.operationWarningCounts[category] || 0;
        if (count >= root.operationWarningLimit)
            return;
        root.operationWarningCounts[category] = count + 1;
        Logger.warn("bluetooth", message);
    }

    function setPowered(value: bool): bool {
        if (typeof value !== "boolean") {
            root.warnOperation("power.invalid", "ignored invalid power request");
            return false;
        }

        const bluetooth = Bluetooth;
        const adapter = bluetooth.defaultAdapter;
        if (adapter === null || adapter === undefined) {
            root.warnOperation("power.adapter", "ignored power request without adapter");
            return false;
        }

        try {
            if (!value && adapter.discovering === true)
                adapter.discovering = false;
            adapter.enabled = value;
            return true;
        } catch (error) {
            root.warnOperation("power.failure", "power request failed");
            return false;
        }
    }

    function setDiscovering(value: bool): bool {
        if (typeof value !== "boolean") {
            root.warnOperation("discovery.invalid", "ignored invalid discovery request");
            return false;
        }

        const adapter = Bluetooth.defaultAdapter;
        if (adapter === null || adapter === undefined || adapter.enabled !== true) {
            root.warnOperation("discovery.adapter", "ignored discovery request without powered adapter");
            return false;
        }

        try {
            adapter.discovering = value;
            return true;
        } catch (error) {
            root.warnOperation("discovery.failure", "discovery request failed");
            return false;
        }
    }

    function connectDevice(address: string): bool {
        const device = root.nativeDeviceForAddress(address);
        if (device === null) {
            root.warnOperation("connect.stale", "ignored connect request for stale device");
            return false;
        }

        try {
            Logger.info("bluetooth", "connectDevice requesting connection for " + address);
            if (Bluetooth.defaultAdapter?.discovering === true)
                Bluetooth.defaultAdapter.discovering = false;
            if (device.paired === true && device.trusted !== true)
                device.trusted = true;
            device.connect();
            return true;
        } catch (error) {
            root.warnOperation("connect.failure", "connect request failed");
            return false;
        }
    }

    function disconnectDevice(address: string): bool {
        const device = root.nativeDeviceForAddress(address);
        if (device === null) {
            root.warnOperation("disconnect.stale", "ignored disconnect request for stale device");
            return false;
        }

        try {
            device.disconnect();
            return true;
        } catch (error) {
            root.warnOperation("disconnect.failure", "disconnect request failed");
            return false;
        }
    }

    function pairDevice(address: string): bool {
        const device = root.nativeDeviceForAddress(address);
        if (device === null) {
            root.warnOperation("pair.stale", "ignored pair request for stale device");
            return false;
        }

        try {
            if (root.pendingPairAddress)
                return false;
            if (root.agentRetry.running || root.agentAttempts >= root.agentAttemptLimit)
                root.resetAgentRetry();
            root.ensureAgent();
            root.pendingPairAddress = BluetoothRules.normalizedAddress(address);
            root.pairWatchdog.restart();
            Logger.info("bluetooth", "pairDevice requesting pair for " + root.pendingPairAddress);
            device.pair();
            return true;
        } catch (error) {
            root.warnOperation("pair.failure", "pair request failed");
            return false;
        }
    }

    function cancelPair(address: string): bool {
        const device = root.nativeDeviceForAddress(address);
        if (device === null) {
            root.warnOperation("cancelPair.stale", "ignored pair cancellation for stale device");
            return false;
        }

        try {
            root.resetPairing();
            if (device.pairing === true)
                device.cancelPair();
            return true;
        } catch (error) {
            root.warnOperation("cancelPair.failure", "pair cancellation failed");
            return false;
        }
    }

    function forgetDevice(address: string): bool {
        const device = root.nativeDeviceForAddress(address);
        if (device === null) {
            root.warnOperation("forget.stale", "ignored forget request for stale device");
            return false;
        }

        try {
            device.forget();
            // Bring the forgotten device back into the discovery section below
            // by resuming discovery, so it reappears as an available device.
            const bluetooth = Bluetooth;
            const adapter = bluetooth.defaultAdapter;
            if (adapter !== null && adapter !== undefined && adapter.enabled === true)
                adapter.discovering = true;
            if (BluetoothRules.normalizedAddress(address).toLowerCase()
                    === root.pendingPairAddress.toLowerCase())
                root.resetPairing();
            return true;
        } catch (error) {
            root.warnOperation("forget.failure", "forget request failed");
            return false;
        }
    }

    function completeAudioConnection(address: string): void {
        if (BluetoothRules.normalizedAddress(address).toLowerCase()
                !== root.pendingPairAddress.toLowerCase())
            return;
        root.pendingPairAddress = "";
        root.pairWatchdog.stop();
        root.connectWatchdog.stop();
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
            pendingPairAddress: root.pendingPairAddress,
            pairingAgentRunning: root.agentProcess.running,
        });
    }

    onProjectionChanged: {
        root.observeAudioConnections();
        root.observePairProgress();
    }
    Component.onCompleted: {
        root.observeAudioConnections();
        root.ensureAgent();
    }
}
