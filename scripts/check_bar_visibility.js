#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Bar", "BarVisibilityRules.js");
const statePath = path.join(root, "Titonium", "Core", "Runtime", "BarVisibilityState.qml");

if (!fs.existsSync(rulesPath)) {
    console.error("FAIL Bar visibility rules are missing");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({ Boolean });
vm.runInContext(source, context, { filename: rulesPath });

assert.equal(context.shouldReveal(true, false, false), true);
assert.equal(context.shouldReveal(false, true, false), true);
assert.equal(context.shouldReveal(false, false, true), true);
assert.equal(context.shouldReveal(false, false, false), false);
assert.equal(context.exclusiveZone(true, 44), 44);
assert.equal(context.exclusiveZone(false, 44), 0);
assert.equal(context.exclusiveZone(true, -1), 0);

console.log("PASS TopBar pin, edge reveal, and exclusive-zone fixtures");

const stateSource = fs.existsSync(statePath) ? fs.readFileSync(statePath, "utf8") : "";
assert.match(stateSource, /readonly property bool pinned: Preferences\.bar\.autoHide !== true/);
assert.match(stateSource, /Preferences\.previewActive\s*\? Preferences\.patch\("modules\.bar\.autoHide", nextAutoHide\)\s*: Preferences\.commitPatch\("modules\.bar\.autoHide", nextAutoHide\)/s);
assert.equal(stateSource.includes("property bool pinned: true"), false,
    "Bar visibility cannot retain independent mutable pin state");
console.log("PASS TopBar visibility maps through transactional Preferences");
