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

assert.equal(typeof rules.presentation, "function",
    "Center activity rules must project separate app and title fields");
assert.deepEqual(JSON.parse(JSON.stringify(rules.presentation(
    "Chrome", "Titonium — Settings", "Active", "Desktop"))),
    { appName: "Chrome", title: "Titonium — Settings" });
assert.deepEqual(JSON.parse(JSON.stringify(rules.presentation(
    "Firefox", "Firefox", "Active", "Desktop"))),
    { appName: "Firefox", title: "Active" });
assert.deepEqual(JSON.parse(JSON.stringify(rules.presentation(
    "", "", "Active", "Desktop"))),
    { appName: "Titonium", title: "Desktop" });
console.log("PASS Center activity two-field presentation fixtures");

const island = fs.readFileSync(islandPath, "utf8");
for (const fragment of [
    "HyprlandService.activeWindow",
    "ApplicationService.nameForAppId",
    "CenterActivityRules.label",
    "implicitWidth: 420",
    "readonly property var presentation:",
    "id: appNameLabel",
    "Layout.maximumWidth: 120",
    "id: activityDot",
    "text: \"·\"",
    "id: titleLabel",
    "outlined: false",
    "Text.ElideRight",
    "maximumLineCount: 1",
]) {
    assert.equal(island.includes(fragment), true, `CenterIsland missing ${fragment}`);
}
assert.equal(island.includes("activityRow.implicitWidth"), false,
    "Center width must not change with the active-window title");
assert.equal(island.includes("id: activitySeparator"), false,
    "Center content must not use a vertical divider");
assert.equal(island.includes("Layout.preferredWidth: 120"), false,
    "short app names must not leave a fixed-width gap before the title");
console.log("PASS fixed-width Center activity presentation contract");
