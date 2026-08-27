#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const helperPath = path.join(__dirname, "..", "Titonium", "Services", "Dock", "DockRules.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL Dock rules are missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({});
vm.runInContext(source, context, { filename: helperPath });
const rules = context;
const plain = value => JSON.parse(JSON.stringify(value));

const normalized = rules.normalizeState({
    $schema: "ignored",
    schemaVersion: 99,
    pinnedIds: ["org.Arch", "", "org.arch", null, "Firefox", "Firefox"],
    pinnedOpen: "yes",
    autoHide: false,
});
assert.deepEqual(plain(normalized), {
    $schema: "titonium.dock/v1",
    schemaVersion: 1,
    pinnedIds: ["org.Arch", "Firefox"],
    pinnedOpen: false,
    autoHide: false,
});
assert.deepEqual(plain(rules.normalizeState({ pinnedIds: [" Unknown " ] }).pinnedIds), ["Unknown"]);
console.log("PASS Dock rules normalization fixtures");

const runningGroups = [
    { appId: "firefox", runningCount: 2, active: true, urgent: false, activeWorkspaceId: 7 },
    { appId: "org.gnome.Nautilus", runningCount: 1, active: false, urgent: true, activeWorkspaceId: 0 },
    { appId: "FIREFOX", runningCount: 3, active: false, urgent: true },
    { appId: "", runningCount: 7, active: true, urgent: true },
];
const entriesById = {
    Firefox: { id: "Firefox", name: "Firefox", icon: "firefox" },
    "org.gnome.Nautilus": { id: "org.gnome.Nautilus", name: "Files", icon: "org.gnome.Nautilus" },
};
const merged = rules.mergeItems(
    ["Firefox", "missing.desktop"],
    runningGroups,
    entriesById,
    ["FIREFOX", "org.gnome.Nautilus", "Firefox"],
);
assert.deepEqual(plain(merged), [
    { appId: "Firefox", name: "Firefox", icon: "firefox", runningCount: 5,
        active: true, urgent: true, pinned: true, workspaceColorIndex: 1 },
    { appId: "org.gnome.Nautilus", name: "Files", icon: "org.gnome.Nautilus", runningCount: 1,
        active: false, urgent: true, pinned: false, workspaceColorIndex: -1 },
]);
assert.deepEqual(plain(rules.mergeItems([], runningGroups, entriesById,
    ["org.gnome.Nautilus", "FIREFOX"]).map(item => item.appId)),
    ["org.gnome.Nautilus", "Firefox"]);
assert.deepEqual(plain(Object.keys(merged[0]).sort()),
    ["active", "appId", "icon", "name", "pinned", "runningCount", "urgent", "workspaceColorIndex"]);
console.log("PASS Dock rules merge fixtures");

assert.equal(rules.nextCycleIndex(-1, 3), 0);
assert.equal(rules.nextCycleIndex(0, 3), 1);
assert.equal(rules.nextCycleIndex(2, 3), 0);
assert.equal(rules.nextCycleIndex(4, 3), 0);
assert.equal(rules.nextCycleIndex(0, 0), -1);
console.log("PASS Dock rules cycle fixtures");

assert.equal(rules.shouldReveal(true, false, 1, false, false), false);
assert.equal(rules.shouldReveal(true, false, 0, false, false), true);
assert.equal(rules.shouldReveal(true, false, 2, true, false), true);
assert.equal(rules.shouldReveal(true, false, 2, false, true), true);
assert.equal(rules.shouldReveal(false, false, 2, false, false), true);
assert.equal(rules.shouldReveal(true, true, 2, false, false), true);
console.log("PASS Dock rules reveal fixtures");

assert.equal(typeof rules.exclusiveZone, "function",
    "Dock rules must own the pinned exclusive-zone decision");
assert.equal(rules.exclusiveZone(true, 56), 56,
    "a pinned Dock reserves only its visible 56px body");
assert.equal(rules.exclusiveZone(false, 56), 0,
    "an unpinned Dock does not reserve the screen edge");
assert.equal(rules.exclusiveZone(true, -4), 0,
    "invalid body heights cannot create a negative reserve");
console.log("PASS Dock exclusive-zone fixtures");
