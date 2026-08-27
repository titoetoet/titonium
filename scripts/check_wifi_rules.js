#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const helperPath = process.env.TITONIUM_WIFI_RULES_PATH
    || path.join(__dirname, "..", "Titonium", "Services", "Network", "WifiRules.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL Wi-Fi rules are missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({});
vm.runInContext(source, context, { filename: helperPath });
const rules = context;
const plain = value => JSON.parse(JSON.stringify(value));

const expectedFields = [
    "connected", "id", "known", "name", "section", "secure", "securityKey", "signal", "signalKey", "stateKey", "transitioning",
];
const assertDescriptor = network => assert.deepEqual(Object.keys(network).sort(), expectedFields);

const unavailable = plain(rules.projectWifi(null));
assert.deepEqual(Object.keys(unavailable).sort(), [
    "available", "connectedName", "networks", "scanning", "stateKey", "wifiEnabled", "wifiHardwareEnabled",
]);
assert.equal(unavailable.available, false);
assert.equal(unavailable.stateKey, "wifi.unavailable");
assert.deepEqual(unavailable.networks, []);

const disabled = plain(rules.projectWifi({ wifiEnabled: false, wifiHardwareEnabled: true, devices: [] }));
assert.equal(disabled.available, true);
assert.equal(disabled.wifiEnabled, false);
assert.equal(disabled.scanning, false);
assert.equal(disabled.stateKey, "wifi.off");

const projected = plain(rules.projectWifi({
    wifiEnabled: true,
    wifiHardwareEnabled: true,
    scanning: true,
    devices: [
        { name: "Guest", signal: 95, secure: false, known: false },
        { name: "Office", signal: 24, secure: true, known: true },
        { name: "Office", signal: 85, secure: true, known: true, connected: true },
        { name: "alpha", signal: 55, secure: true, known: false },
        { name: "Beta", signal: 55, secure: true, known: false },
        { name: "guest", signal: 4, secure: true, known: true },
        { name: "  ", signal: 90, secure: true },
    ],
}));
assert.equal(projected.connectedName, "Office");
assert.equal(projected.scanning, true);
assert.equal(projected.stateKey, "wifi.scanning");
assert.deepEqual(projected.networks.map(network => network.name), ["Office", "guest", "Guest", "alpha", "Beta"]);
assert.deepEqual(projected.networks.map(network => network.section), ["connected", "known", "available", "available", "available"]);
assert.equal(projected.networks[0].signal, 85);
assert.equal(projected.networks[0].stateKey, "wifi.network.connected");
assert.equal(projected.networks[0].securityKey, "wifi.security.secured");
assert.equal(projected.networks[2].securityKey, "wifi.security.open");
assert.equal(projected.networks[0].signalKey, "wifi.signal.excellent");
assert.equal(projected.networks[3].signalKey, "wifi.signal.good");
projected.networks.forEach(assertDescriptor);
assert.ok(!JSON.stringify(projected).match(/password|psk|secret/i));

const stateChanging = plain(rules.projectWifi({
    wifiEnabled: true,
    wifiHardwareEnabled: true,
    devices: [{ name: "Cafe", signal: 20, secure: true, state: "connecting" }],
}));
assert.equal(stateChanging.networks[0].stateKey, "wifi.network.connecting");
assert.equal(stateChanging.networks[0].transitioning, true);
assert.equal(stateChanging.stateKey, "wifi.on");

const connected = plain(rules.projectWifi({
    wifiEnabled: true,
    wifiHardwareEnabled: true,
    devices: [{ name: "Home", signal: 0, secure: true, connected: true }],
}));
assert.equal(connected.stateKey, "wifi.connected");
assert.equal(connected.networks[0].signalKey, "wifi.signal.none");

const weakKnownNative = { token: "weak-known" };
const strongUnknownNative = { token: "strong-unknown" };
const connectedNative = { token: "connected" };
assert.strictEqual(rules.preferredNativeForId([
    { native: weakKnownNative, name: "Office", signal: 20, known: true },
    { native: strongUnknownNative, name: "Office", signal: 90, known: false },
    { native: connectedNative, name: "Office", signal: 1, known: true, connected: true },
], "Office"), connectedNative);
assert.strictEqual(rules.preferredNativeForId([
    { native: weakKnownNative, name: "Office", signal: 20, known: true },
    { native: strongUnknownNative, name: "Office", signal: 90, known: false },
], "Office"), strongUnknownNative);

console.log("PASS Wi-Fi rules fixtures");
