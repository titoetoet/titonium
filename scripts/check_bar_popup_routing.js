#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Bar", "right", "BarPopupRouting.js");
assert.equal(fs.existsSync(rulesPath), true, "BarPopupRouting rules must exist");

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const routing = vm.createContext({});
vm.runInContext(source, routing, { filename: rulesPath });

assert.equal(routing.normalizeStyle("classic"), "classic");
assert.equal(routing.normalizeStyle("CONNECTED"), "connected");
assert.deepEqual(JSON.parse(JSON.stringify(routing.presentation("connected", "network"))), {
    owner: "edge", source: "ConnectedNetworkPopupContent.qml", anchor: "network"
});
assert.deepEqual(JSON.parse(JSON.stringify(routing.presentation("classic", "network"))), {
    owner: "overlay", source: "ClassicNetworkPopupSurface.qml", anchor: ""
});
assert.deepEqual(JSON.parse(JSON.stringify(routing.presentation("connected", "audio"))), {
    owner: "edge", source: "ConnectedAudioPopupContent.qml", anchor: "audio"
});
assert.equal(routing.presentation("classic", "input").owner, "overlay");
assert.equal(routing.presentation("connected", "unknown"), null);

console.log("PASS Bar popup style routing");
