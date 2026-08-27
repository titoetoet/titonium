#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const helperPath = path.join(__dirname, "..", "Titonium", "Services", "Bluetooth", "BluetoothRules.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL Bluetooth rules are missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({});
vm.runInContext(source, context, { filename: helperPath });
const rules = context;
const plain = value => JSON.parse(JSON.stringify(value));

const noAdapter = plain(rules.projectAdapter(null));
assert.deepEqual(Object.keys(noAdapter).sort(), [
    "adapterName", "available", "connectedCount", "devices", "discovering", "powered", "stateKey",
]);
assert.equal(noAdapter.available, false);
assert.equal(noAdapter.powered, false);
assert.equal(noAdapter.discovering, false);
assert.equal(noAdapter.stateKey, "bluetooth.unavailable");
assert.deepEqual(noAdapter.devices, []);

const poweredOff = plain(rules.projectAdapter({
    name: "Laptop radio",
    enabled: false,
    discovering: true,
    devices: [{ address: "AA:BB", name: "Remembered", paired: true }],
}));
assert.equal(poweredOff.available, true);
assert.equal(poweredOff.powered, false);
assert.equal(poweredOff.discovering, false);
assert.equal(poweredOff.stateKey, "bluetooth.off");
assert.deepEqual(poweredOff.devices, []);

const projected = plain(rules.projectAdapter({
    name: "Laptop radio",
    enabled: true,
    discovering: true,
    devices: [
        { address: "CC:00", name: "zeta", icon: "audio-headphones", connected: true, paired: true, batteryAvailable: true, battery: 121 },
        { address: "BB:00", name: "Alpha", paired: true, batteryAvailable: true, battery: -8 },
        { address: "DD:00", name: "alpha", pairing: true, batteryAvailable: true, battery: 55.8 },
        { address: "AA:00", name: "alpha", paired: true },
        { address: "cc:00", name: "Ignored duplicate", connected: true },
        { address: "EE:00", name: "Blocked", blocked: true },
    ],
}));
assert.equal(projected.available, true);
assert.equal(projected.powered, true);
assert.equal(projected.discovering, true);
assert.equal(projected.stateKey, "bluetooth.scanning");
assert.equal(projected.connectedCount, 1);
assert.deepEqual(projected.devices.map(device => device.address), ["CC:00", "DD:00", "AA:00", "BB:00", "EE:00"]);
assert.deepEqual(projected.devices.map(device => device.section), ["connected", "paired", "paired", "paired", "available"]);
assert.deepEqual(projected.devices.map(device => device.stateKey), [
    "bluetooth.device.connected",
    "bluetooth.device.pairing",
    "bluetooth.device.paired",
    "bluetooth.device.paired",
    "bluetooth.device.blocked",
]);
assert.deepEqual(Object.keys(projected.devices[0]).sort(), [
    "address", "battery", "batteryAvailable", "blocked", "connected", "icon", "name", "paired", "pairing", "section", "stateKey",
]);
assert.equal(projected.devices[0].battery, 100);
assert.equal(projected.devices[0].batteryAvailable, true);
assert.equal(projected.devices[1].battery, 56);
assert.equal(projected.devices[1].batteryAvailable, true);
assert.equal(projected.devices[2].batteryAvailable, false);
assert.equal(projected.devices[2].battery, 0);
assert.notStrictEqual(projected.devices[0], projected.devices[1]);

const connected = plain(rules.projectAdapter({
    enabled: true,
    discovering: false,
    devices: [{ address: "11:22", name: "Keyboard", connected: true }],
}));
assert.equal(connected.stateKey, "bluetooth.connected");
assert.equal(connected.connectedCount, 1);

const poweredOn = plain(rules.projectAdapter({ enabled: true, discovering: false, devices: [] }));
assert.equal(poweredOn.stateKey, "bluetooth.on");

console.log("PASS Bluetooth rules fixtures");
