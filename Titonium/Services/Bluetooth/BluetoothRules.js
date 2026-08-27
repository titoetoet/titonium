.pragma library

function normalizedAddress(address) {
    return typeof address === "string" ? address.trim() : "";
}

function caseFold(value) {
    return value.toLowerCase();
}

function text(value, fallback) {
    if (typeof value !== "string")
        return fallback;

    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : fallback;
}

function clampedBattery(value) {
    if (typeof value !== "number" || !Number.isFinite(value))
        return 0;

    return Math.round(Math.max(0, Math.min(100, value)));
}

function deviceStateKey(device) {
    if (device.blocked === true)
        return "bluetooth.device.blocked";
    if (device.connecting === true)
        return "bluetooth.device.connecting";
    if (device.disconnecting === true)
        return "bluetooth.device.disconnecting";
    if (device.connected === true)
        return "bluetooth.device.connected";
    if (device.pairing === true)
        return "bluetooth.device.pairing";
    if (device.paired === true)
        return "bluetooth.device.paired";
    return "bluetooth.device.available";
}

function normalizedDevice(device) {
    const address = normalizedAddress(device?.address);
    if (address.length === 0)
        return null;

    const connected = device?.connected === true;
    const paired = device?.paired === true;
    const pairing = device?.pairing === true;
    const batteryAvailable = device?.batteryAvailable === true;
    const result = {
        address: address,
        name: text(device?.name, address),
        icon: text(device?.icon, "bluetooth"),
        section: connected ? "connected" : (pairing || paired ? "paired" : "available"),
        stateKey: "",
        connected: connected,
        paired: paired,
        pairing: pairing,
        batteryAvailable: batteryAvailable,
        battery: batteryAvailable ? clampedBattery(device?.battery) : 0,
        blocked: device?.blocked === true,
    };
    result.stateKey = deviceStateKey(device || {});
    return result;
}

function sectionRank(device) {
    if (device.section === "connected")
        return 0;
    if (device.section === "paired")
        return 1;
    return 2;
}

function compareDevices(left, right) {
    const sectionDifference = sectionRank(left) - sectionRank(right);
    if (sectionDifference !== 0)
        return sectionDifference;

    if (left.pairing !== right.pairing)
        return left.pairing ? -1 : 1;

    const leftName = caseFold(left.name);
    const rightName = caseFold(right.name);
    if (leftName < rightName)
        return -1;
    if (leftName > rightName)
        return 1;

    const leftAddress = caseFold(left.address);
    const rightAddress = caseFold(right.address);
    if (leftAddress < rightAddress)
        return -1;
    if (leftAddress > rightAddress)
        return 1;
    return 0;
}

function normalizedDevices(devices) {
    const values = Array.isArray(devices) ? devices : [];
    const seen = Object.create(null);
    const result = [];

    for (let index = 0; index < values.length; index += 1) {
        const device = normalizedDevice(values[index]);
        if (device === null)
            continue;

        const key = caseFold(device.address);
        if (seen[key] === true)
            continue;

        seen[key] = true;
        result.push(device);
    }

    return result.sort(compareDevices);
}

function adapterStateKey(available, powered, discovering, connectedCount) {
    if (!available)
        return "bluetooth.unavailable";
    if (!powered)
        return "bluetooth.off";
    if (discovering)
        return "bluetooth.scanning";
    if (connectedCount > 0)
        return "bluetooth.connected";
    return "bluetooth.on";
}

function projectAdapter(adapter) {
    const available = adapter !== null && typeof adapter === "object";
    const powered = available && adapter.enabled === true;
    const discovering = powered && adapter.discovering === true;
    const devices = powered ? normalizedDevices(adapter.devices) : [];
    const connectedCount = devices.filter(device => device.connected).length;

    return {
        available: available,
        powered: powered,
        discovering: discovering,
        adapterName: available ? text(adapter.name, "Bluetooth") : "",
        connectedCount: connectedCount,
        devices: devices,
        stateKey: adapterStateKey(available, powered, discovering, connectedCount),
    };
}

function audioConnectionEvent(previousAddresses, devices) {
    const previous = Array.isArray(previousAddresses) ? previousAddresses : [];
    const previousSet = Object.create(null);
    previous.forEach(address => previousSet[caseFold(normalizedAddress(address))] = true);
    const current = [];
    const connected = [];
    const disconnected = [];
    const seen = Object.create(null);
    const source = Array.isArray(devices) ? devices : [];
    source.forEach(device => {
        const address = normalizedAddress(device?.address);
        const key = caseFold(address);
        const icon = text(device?.icon, "");
        if (!address || seen[key] || device?.connected !== true || icon.indexOf("audio-") !== 0)
            return;
        seen[key] = true;
        current.push(key);
        if (previousSet[key] !== true)
            connected.push(address);
    });
    previous.forEach(address => {
        const key = caseFold(normalizedAddress(address));
        if (key && seen[key] !== true)
            disconnected.push(key);
    });
    return { current: current, connected: connected, disconnected: disconnected };
}
