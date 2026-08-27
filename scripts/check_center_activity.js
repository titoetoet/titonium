#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Bar", "islands", "CenterActivityRules.js");
const islandPath = path.join(root, "Titonium", "Bar", "islands", "CenterIsland.qml");

if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing Titonium/Bar/islands/CenterActivityRules.js");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

assert.equal(rules.label("Codex", "Phân tích Titonium"), "Codex · Phân tích Titonium");
assert.equal(rules.label("Firefox", "Firefox"), "Firefox");
assert.equal(rules.label("", ""), "Titonium");
assert.equal(rules.label("Kitty", "   "), "Kitty");
assert.equal(rules.label("", "  Clipboard  "), "Clipboard");
console.log("PASS Center activity label normalization fixtures");

const island = fs.readFileSync(islandPath, "utf8");
for (const fragment of [
    "HyprlandService.activeWindow",
    "ApplicationService.nameForAppId",
    "CenterActivityRules.label",
    "Math.min(520",
    "Text.ElideRight",
    "maximumLineCount: 1",
]) {
    assert.equal(island.includes(fragment), true, `CenterIsland missing ${fragment}`);
}
console.log("PASS adaptive Center activity presentation contract");
