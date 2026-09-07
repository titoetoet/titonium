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
assert.equal(context.shouldReveal(false, false, true, true), false,
    "clicking unpin must ignore the hover which caused the click");
assert.equal(context.shouldReveal(false, true, true, true), false,
    "the current top-edge hover must not immediately reopen an explicitly hidden bar");
assert.equal(context.shouldReveal(false, true, false, false), true,
    "a fresh edge entry reveals the unpinned bar again");
assert.equal(context.shouldReveal(true, false, true, true), true,
    "pinning always restores the bar");
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

// Execute the production toggle against successful and rejected transactions.
const toggleBody = stateSource.match(/function togglePinned\(\): bool \{([\s\S]*?)\n    \}/)[1];
for (const previewActive of [false, true]) {
    for (const pinned of [false, true]) {
        for (const accepted of [false, true]) {
            let hidden = 0;
            const writes = [];
            const state = { pinned, hideRequested() { hidden++; } };
            const preferences = {
                previewActive,
                patch(path, value) { writes.push(["preview", path, value]); return accepted; },
                commitPatch(path, value) { writes.push(["commit", path, value]); return accepted; },
            };
            const toggle = new Function("root", "Preferences", toggleBody);
            assert.equal(toggle(state, preferences), accepted);
            assert.equal(hidden, accepted && pinned ? 1 : 0);
            assert.deepEqual(writes, [[previewActive ? "preview" : "commit", "modules.bar.autoHide", pinned]]);
        }
    }
}
console.log("PASS Explicit unpin hides only after an accepted preferences transaction");

// Gaps in a revealed auto-hide bar must retain hover for the whole band.
assert.equal(context.revealRegionHeight(false, true, 44, 2), 44);
assert.equal(context.revealRegionHeight(false, false, 44, 2), 2);
assert.equal(context.revealRegionHeight(true, true, 44, 2), 2,
    "pinned gaps keep their existing click-through mask");
const hoverBody = stateSource.match(/function setCenterHovered\(screenName: string, hovered: bool\): void \{([\s\S]*?)\n    \}/)[1];
const readHoverBody = stateSource.match(/function centerHovered\(screenName: string\): bool \{([\s\S]*?)\n    \}/)[1];
const hoverState = {centerHoverByScreen: {}};
const setHovered = (screen, hovered) => new Function("root", "screenName", "hovered", hoverBody)(hoverState,screen,hovered);
const isHovered = screen => new Function("root", "screenName", readHoverBody)(hoverState,screen);
hoverState.centerHovered = isHovered;
setHovered("DP-1",true);assert.equal(isHovered("DP-1"),true);assert.equal(isHovered("DP-3"),false);
setHovered("DP-3",true);setHovered("DP-1",false);
assert.equal(isHovered("DP-1"),false);assert.equal(isHovered("DP-3"),true);
setHovered("DP-3",false);assert.deepEqual(hoverState.centerHoverByScreen,{});
console.log("PASS revealed hover band and screen-scoped Center retention cleanup");
