#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const helperPath = path.join(__dirname, "..", "Titonium", "Bar", "notch", "BarLayout.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL Bar layout helper is missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({ Math, Number, isFinite });
vm.runInContext(source, context, { filename: helperPath });
const plain = value => JSON.parse(JSON.stringify(value));

assert.equal(context.centerX(1920, 180), 870, "center is based on the screen width");
assert.equal(context.centerX(1280, 180), 550, "center works at a second width");
assert.equal(
    context.centerX(1920, 180),
    context.centerX(1920, 180, 600, 300),
    "outer island widths cannot influence true center",
);
assert.equal(context.centerX(-10, 180), 0, "invalid width clamps to the left edge");
assert.deepEqual(
    plain(context.optionalVisibility(1000, 260, 180, 260, 8)),
    { showActiveWindow: true, showConnectivityDiagnostics: true },
    "optional groups remain visible when all islands fit",
);
assert.deepEqual(
    plain(context.optionalVisibility(700, 260, 180, 260, 8)),
    { showActiveWindow: false, showConnectivityDiagnostics: false },
    "optional groups yield before protected center and status content",
);

console.log("PASS Bar layout fixtures (6)");
