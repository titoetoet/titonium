#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const helperPath = path.join(__dirname, "..", "Titonium", "Bar", "notch", "CenterNotchState.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL Center Notch state helper is missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({ Math, Number, isFinite });
vm.runInContext(source, context, { filename: helperPath });
const plain = value => JSON.parse(JSON.stringify(value));

assert.deepEqual(plain(context.primaryPages()), [
    { id: "overview", icon: "dashboard" },
], "Center exposes Dashboard as its only page");
assert.equal(context.normalizePage("unknown"), "overview", "unknown page falls back safely");
assert.equal(context.normalizePage("monitoring"), "overview",
    "System Monitoring is detached from Center");
assert.equal(context.normalizePage("notifications"), "notifications",
    "notifications remain available as a direct hidden route");
assert.equal(context.arrowPage("overview", -1), "overview", "Dashboard navigation is stable");
assert.equal(context.arrowPage("overview", 1), "overview", "Dashboard navigation stays put");
assert.equal(context.wheelPage("overview", -1), "overview", "wheel clamps at the first page");
assert.equal(context.wheelPage("overview", 1), "overview", "wheel stays on Dashboard");
assert.deepEqual(
    plain(context.transitionPlan("overview", "overview", true, 160)),
    { duration: 0, offset: 12 },
    "reduced motion removes duration while preserving direction",
);
assert.equal(
    context.transitionPlan("overview", "overview", false, 900).duration,
    220,
    "transition duration is bounded",
);
assert.equal(context.transitionPlan("overview", "overview", false, 160).offset, 12,
    "single-page transition remains deterministic");

assert.deepEqual(
    plain(context.pinTransition("", "DP-1", false, "toggle")),
    { ownerScreenName: "DP-1", pinned: true, shouldClose: false },
    "pin opens Center on the requested screen",
);
assert.deepEqual(
    plain(context.pinTransition("DP-1", "DP-1", true, "toggle")),
    { ownerScreenName: "", pinned: false, shouldClose: true },
    "toggling an active pin closes and clears it",
);
assert.deepEqual(
    plain(context.pinTransition("DP-1", "DP-3", false, "toggle")),
    { ownerScreenName: "DP-3", pinned: true, shouldClose: false },
    "pin ownership transfers to the requested screen",
);
assert.deepEqual(
    plain(context.pinTransition("DP-1", "DP-1", true, "close")),
    { ownerScreenName: "", pinned: false, shouldClose: true },
    "explicit close always clears pin state",
);

console.log("PASS Dashboard Center Notch with direct notification route fixtures");

const barRoot = path.join(__dirname, "..", "Titonium", "Bar");
const sources = Object.fromEntries([
    "CenterNotch.qml", "CenterNotchSurface.qml", "CenterNotchWindow.qml", "../BarHost.qml",
].map(relative => {
    const file = path.join(barRoot, "notch", relative);
    return [relative, fs.existsSync(file) ? fs.readFileSync(file, "utf8") : ""];
}));
assert.doesNotMatch(sources["CenterNotch.qml"], /CenterNotchRail/);
assert.doesNotMatch(sources["CenterNotch.qml"], /settingsRequested/);
assert.doesNotMatch(sources["CenterNotchSurface.qml"], /settingsRequested/);
console.log("PASS Center Notch owns Dashboard and direct notification history");
