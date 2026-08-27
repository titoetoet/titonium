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

assert.equal(context.normalizePage("unknown"), "overview", "unknown page falls back safely");
assert.equal(context.arrowPage("overview", -1), "session", "Up wraps to the final primary page");
assert.equal(context.arrowPage("session", 1), "overview", "Down wraps to the first primary page");
assert.equal(context.wheelPage("overview", -1), "overview", "wheel clamps at the first page");
assert.equal(context.wheelPage("session", 1), "session", "wheel clamps at the final page");
assert.deepEqual(
    plain(context.transitionPlan("overview", "tools", true, 160)),
    { duration: 0, offset: 12 },
    "reduced motion removes duration while preserving direction",
);
assert.equal(
    context.transitionPlan("overview", "session", false, 900).duration,
    220,
    "transition duration is bounded",
);
assert.equal(
    context.transitionPlan("session", "tools", false, 160).offset,
    -12,
    "reverse navigation uses an upward offset",
);

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

console.log("PASS Center Notch state fixtures (12)");
