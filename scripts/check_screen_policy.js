#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const helperPath = path.join(root, "Titonium", "Core", "Screens", "ScreenPolicy.js");

if (!fs.existsSync(helperPath)) {
    console.error("FAIL screen policy helper is missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({});
vm.runInContext(source, context, { filename: helperPath });

const dp3 = { name: "DP-3", width: 3440, height: 1440 };
const dp1 = { name: "DP-1", width: 3840, height: 2160 };

assert.deepEqual(
    Array.from(context.eligibleScreens([dp3, dp1], "DP-1"), screen => screen.name),
    ["DP-1"],
    "Titonium must expose only DP-1 when both outputs are connected",
);
assert.equal(context.acceptsScreen(dp1, "DP-1"), true);
assert.equal(context.acceptsScreen(dp3, "DP-1"), false);
assert.equal(context.eligibleScreens([dp3], "DP-1").length, 0,
    "disconnecting DP-1 must not fall back to another output");
assert.deepEqual(
    Array.from(context.eligibleScreens([dp3, dp1], "DP-1"), screen => screen.name),
    ["DP-1"],
    "reconnecting DP-1 must make it eligible again",
);
assert.equal(context.eligibleScreens([dp1], "").length, 0,
    "an empty target must fail closed");

const requiredHosts = [
    "Titonium/Bar/BarHost.qml",
    "Titonium/Core/Surfaces/OverlayHost.qml",
    "Titonium/Osd/Audio/AudioOsdHost.qml",
];
for (const relative of requiredHosts) {
    const hostSource = fs.readFileSync(path.join(root, relative), "utf8");
    assert.match(hostSource, /model:\s*ScreenPolicy\.screens/,
        `${relative} must use the shared eligible-screen model`);
}

const routerSource = fs.readFileSync(
    path.join(root, "Titonium/Core/Screens/ScreenRouter.qml"), "utf8");
assert.match(routerSource, /ScreenPolicy\.acceptsScreen\(root\.activeScreen\)/,
    "ScreenRouter must reject an active screen outside the policy");
assert.match(routerSource, /ScreenPolicy\.screens/,
    "ScreenRouter fallback and named lookup must stay inside the policy");

console.log("PASS DP-1-only screen policy fixtures");
