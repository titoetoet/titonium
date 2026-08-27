#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Hyprland", "WindowRules.js");
const registryPath = path.join(root, "Titonium", "Services", "Hyprland", "WindowRegistry.js");
const servicePath = path.join(root, "Titonium", "Services", "Hyprland", "HyprlandService.qml");
const dockPath = path.join(root, "Titonium", "Services", "Dock", "DockService.qml");

function loadLibrary(file) {
    if (!fs.existsSync(file)) {
        console.error(`FAIL missing ${path.relative(root, file)}`);
        process.exit(1);
    }
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*\n/, "");
    const context = vm.createContext({});
    vm.runInContext(source, context, { filename: file });
    return context;
}

const rules = loadLibrary(rulesPath);
const plain = value => JSON.parse(JSON.stringify(value));

const first = rules.descriptor({
    id: " 0xabc ",
    appId: "",
    ipcClass: "org.mozilla.firefox",
    title: "  Documentation ",
    icon: "firefox",
    active: 1,
    urgent: false,
    minimized: false,
    workspaceId: 7,
    monitorName: " DP-1 ",
    wayland: { activate() {} },
    workspace: { activate() {} },
    native: { secret: true },
});
assert.deepEqual(plain(first), {
    id: "0xabc",
    appId: "org.mozilla.firefox",
    title: "Documentation",
    icon: "firefox",
    active: true,
    urgent: false,
    minimized: false,
    workspaceId: 7,
    monitorName: "DP-1",
});
assert.deepEqual(Object.keys(first), ["id", "appId", "title", "icon", "active", "urgent", "minimized", "workspaceId", "monitorName"]);
assert.equal(Object.isFrozen(first), true);
assert.equal("wayland" in first, false);
assert.equal("workspace" in first, false);
assert.equal("native" in first, false);

const fallback = rules.descriptor({
    id: "0xdef",
    title: "Terminal",
    active: false,
    urgent: true,
    minimized: true,
});
assert.equal(fallback.appId, "Terminal");
assert.equal(fallback.title, "Terminal");
assert.equal(fallback.workspaceId, 0);
assert.equal(fallback.monitorName, "");
assert.equal(rules.descriptor({ id: "0xghi", workspaceId: -2 }).workspaceId, 0);
assert.equal(rules.descriptor({ id: "0xjkl", monitorName: 42 }).monitorName, "");
assert.equal(rules.descriptor({ id: "", appId: "ignored" }), null);
console.log("PASS Window descriptor identity, fallback, immutability, and raw-object rejection fixtures");

assert.deepEqual(plain(rules.mruIds(["gone", "0x2", "0x1"], [
    { id: "0x1", active: false },
    { id: "0x2", active: true },
    { id: "0x3", active: false },
])), ["0x2", "0x1", "0x3"]);
assert.deepEqual(plain(rules.orderByIds([
    { id: "0x1" }, { id: "0x2" }, { id: "0x3" },
], ["0x2", "0x1", "0x3"]).map(window => window.id)), ["0x2", "0x1", "0x3"]);
console.log("PASS Window MRU input fixtures");

const registry = loadLibrary(registryPath).create();
const activationOrder = [];
let closed = 0;
const native = {
    address: "0xabc",
    workspace: {
        activate() { activationOrder.push("workspace"); },
    },
    wayland: {
        activate() { activationOrder.push("window"); },
        close() { closed += 1; },
    },
};
registry.replace([{ id: "0xabc", native }]);
assert.equal(registry.focus("0xabc", [native]), true);
assert.equal(registry.close("0xabc", [native]), true);
assert.deepEqual(activationOrder, ["workspace", "window"]);
assert.equal(closed, 1);
assert.equal(registry.focus("0xabc", []), false);
assert.equal(registry.close("missing", [native]), false);
assert.deepEqual(Object.keys(registry).sort(), ["close", "focus", "replace"]);
assert.equal(JSON.stringify(registry).includes("0xabc"), false);
console.log("PASS Window private registry re-lookup fixtures");

const serviceSource = fs.readFileSync(servicePath, "utf8");
const dockSource = fs.readFileSync(dockPath, "utf8");
assert.equal((serviceSource.match(/Hyprland\.toplevels/g) || []).length > 0, true);
assert.equal(dockSource.includes("Hyprland.toplevels"), false);
assert.equal(dockSource.includes("import Quickshell.Hyprland"), false);
assert.equal(dockSource.includes("DockNativeRegistry"), false);
assert.equal(dockSource.includes("HyprlandService.windows"), true);
assert.equal(dockSource.includes("HyprlandService.focusWindow"), true);
assert.equal(dockSource.includes("HyprlandService.activateWindow"), false);
assert.equal(dockSource.includes("HyprlandService.closeWindow"), true);
const nativeOwners = [];
function collectNativeOwners(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
        const file = path.join(directory, entry.name);
        if (entry.isDirectory())
            collectNativeOwners(file);
        else if (/\.(qml|js)$/.test(entry.name)
                && fs.readFileSync(file, "utf8").includes("Hyprland.toplevels"))
            nativeOwners.push(path.relative(root, file));
    }
}
collectNativeOwners(path.join(root, "Titonium"));
assert.deepEqual(nativeOwners, ["Titonium/Services/Hyprland/HyprlandService.qml"]);
console.log("PASS Sole native window ownership and Dock consumer fixtures");
