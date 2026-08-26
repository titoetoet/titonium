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

console.log("PASS Center Notch state fixtures (8)");
