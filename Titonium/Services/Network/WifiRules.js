.pragma library

function text(value, fallback) {
    if (typeof value !== "string")
        return fallback;
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : fallback;
}

function signal(value) {
    if (typeof value !== "number" || !Number.isFinite(value))
        return 0;
    return Math.round(Math.max(0, Math.min(1, value)) * 100);
}

function signalKey(value) {
    if (value >= 80)
        return "wifi.signal.excellent";
    if (value >= 55)
        return "wifi.signal.good";
    if (value >= 30)
        return "wifi.signal.fair";
    if (value > 0)
        return "wifi.signal.weak";
    return "wifi.signal.none";
}

function signalIcon(value) {
    const strength = typeof value === "number" && Number.isFinite(value)
        ? Math.max(0, Math.min(100, value)) : 0;
    if (strength >= 80)
        return "network_wifi";
    if (strength >= 55)
        return "network_wifi_3_bar";
    if (strength >= 30)
        return "network_wifi_2_bar";
    if (strength > 0)
        return "network_wifi_1_bar";
    return "signal_wifi_0_bar";
}

function barIcon(available, wifiEnabled, wifiHardwareEnabled, scanning, connectedName,
                 connectedSignal) {
    if (available !== true || wifiHardwareEnabled !== true || wifiEnabled !== true)
        return "wifi_off";
    if (typeof connectedName === "string" && connectedName.length > 0)
        return signalIcon(connectedSignal);
    return scanning === true ? "wifi_find" : "signal_wifi_0_bar";
}

function securityKey(secure) {
    return secure ? "wifi.security.secured" : "wifi.security.open";
}

function networkStateKey(network) {
    if (network.connected)
        return "wifi.network.connected";
    if (network.state === "connecting")
        return "wifi.network.connecting";
    if (network.state === "disconnecting")
        return "wifi.network.disconnecting";
    if (network.known)
        return "wifi.network.known";
    return "wifi.network.available";
}

function normalizedNetwork(network) {
    const name = text(network?.name, "");
    if (!name)
        return null;

    const connected = network?.connected === true;
    const known = connected || network?.known === true;
    const state = text(network?.state, "").toLowerCase();
    const strength = signal(network?.signal);
    const result = {
        id: name,
        name: name,
        section: connected ? "connected" : (known ? "known" : "available"),
        connected: connected,
        known: known,
        transitioning: state === "connecting" || state === "disconnecting",
        signal: strength,
        signalIcon: signalIcon(strength),
        signalKey: signalKey(strength),
        secure: network?.secure === true,
        securityKey: securityKey(network?.secure === true),
        stateKey: "",
    };
    result.stateKey = networkStateKey({
        connected: connected,
        known: known,
        state: state,
    });
    return result;
}

function preferredDuplicate(previous, candidate) {
    if (candidate.connected !== previous.connected)
        return candidate.connected ? candidate : previous;
    if (candidate.signal !== previous.signal)
        return candidate.signal > previous.signal ? candidate : previous;
    if (candidate.known !== previous.known)
        return candidate.known ? candidate : previous;
    return previous;
}

function sectionRank(network) {
    if (network.section === "connected")
        return 0;
    if (network.section === "known")
        return 1;
    return 2;
}

function compareNetworks(left, right) {
    const sectionDifference = sectionRank(left) - sectionRank(right);
    if (sectionDifference !== 0)
        return sectionDifference;
    if (left.signal !== right.signal)
        return right.signal - left.signal;
    const leftName = left.name.toLowerCase();
    const rightName = right.name.toLowerCase();
    if (leftName < rightName)
        return -1;
    if (leftName > rightName)
        return 1;
    return 0;
}

function normalizedNetworks(networks) {
    const source = Array.isArray(networks) ? networks : [];
    const byName = Object.create(null);
    source.forEach(value => {
        const network = normalizedNetwork(value);
        if (network === null)
            return;
        const existing = byName[network.id];
        byName[network.id] = existing ? preferredDuplicate(existing, network) : network;
    });
    return Object.keys(byName).map(id => byName[id]).sort(compareNetworks);
}

function preferredNativeForId(candidates, id) {
    const target = text(id, "");
    const source = Array.isArray(candidates) ? candidates : [];
    let preferred = null;
    source.forEach(candidate => {
        const descriptor = normalizedNetwork(candidate);
        if (descriptor === null || descriptor.id !== target)
            return;
        if (preferred === null || preferredDuplicate(preferred.descriptor, descriptor) === descriptor)
            preferred = { descriptor: descriptor, native: candidate.native };
    });
    return preferred ? preferred.native : null;
}

function stateKey(available, wifiEnabled, wifiHardwareEnabled, scanning, connectedName) {
    if (!available)
        return "wifi.unavailable";
    if (!wifiHardwareEnabled)
        return "wifi.hardware_off";
    if (!wifiEnabled)
        return "wifi.off";
    if (scanning)
        return "wifi.scanning";
    if (connectedName)
        return "wifi.connected";
    return "wifi.on";
}

function projectWifi(adapter) {
    const available = adapter !== null && typeof adapter === "object";
    const wifiHardwareEnabled = available && adapter.wifiHardwareEnabled !== false;
    const wifiEnabled = wifiHardwareEnabled && adapter.wifiEnabled === true;
    const scanning = wifiEnabled && adapter.scanning === true;
    const networks = wifiEnabled ? normalizedNetworks(adapter?.devices) : [];
    const connected = networks.find(network => network.connected);
    const connectedName = connected ? connected.name : "";
    const connectedSignal = connected ? connected.signal : 0;
    return {
        available: available,
        wifiEnabled: wifiEnabled,
        wifiHardwareEnabled: wifiHardwareEnabled,
        scanning: scanning,
        connectedName: connectedName,
        connectedSignal: connectedSignal,
        iconName: barIcon(available, wifiEnabled, wifiHardwareEnabled, scanning,
            connectedName, connectedSignal),
        networks: networks,
        stateKey: stateKey(available, wifiEnabled, wifiHardwareEnabled, scanning, connectedName),
    };
}
