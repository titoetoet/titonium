#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Orchestration", "NotificationPanelRouting.js");
assert.equal(fs.existsSync(rulesPath), true, "NotificationPanelRouting rules must exist");

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const routing = vm.createContext({});
vm.runInContext(source, routing, { filename: rulesPath });
const plain = value => JSON.parse(JSON.stringify(value));

assert.equal(routing.ownerId("DP-1"), "notification-panel:DP-1");
assert.equal(routing.ownerId("  DP-2  "), "notification-panel:DP-2");
assert.equal(routing.ownerId(""), "");
assert.equal(routing.toggleAction("", "notification-panel:DP-1"), "open");
assert.equal(routing.toggleAction("spotlight:DP-1", "notification-panel:DP-1"), "replace");
assert.equal(routing.toggleAction("notification-panel:DP-1",
    "notification-panel:DP-2"), "replace");
assert.equal(routing.toggleAction("notification-panel:DP-1",
    "notification-panel:DP-1"), "close");
assert.equal(routing.toggleAction("notification-panel:DP-1", ""), "reject");

assert.equal(typeof routing.presentation, "function",
    "NotificationPanelRouting must expose a pure style presentation rule");
assert.deepEqual(plain(routing.presentation("connected")), {
    owner: "edge",
    source: "ConnectedNotificationPanelContent.qml",
    anchor: "notifications",
}, "Connected Notification Center must route through the exact right-pill control");
assert.deepEqual(plain(routing.presentation("classic")), {
    owner: "overlay",
    source: "ClassicNotificationPanel.qml",
    anchor: "",
}, "Classic Notification Center must retain its detached overlay");
assert.deepEqual(plain(routing.presentation("unknown")), {
    owner: "edge",
    source: "ConnectedNotificationPanelContent.qml",
    anchor: "notifications",
}, "unknown style values must fail closed to the shipped Connected presentation");

console.log("PASS style-aware notification panel and screen-owner routing");
