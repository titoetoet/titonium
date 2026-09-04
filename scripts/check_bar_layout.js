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
assert.equal(typeof context.symmetricCenterReservation, "function",
    "Bar layout must expose a symmetric Center collision reservation");
const connectedCenterReservation = context.symmetricCenterReservation(220, 52);
const classicCenterReservation = context.symmetricCenterReservation(220, 52 + 8);
assert.equal(connectedCenterReservation, 324,
    "Connected must mirror the joined 52px secondary extent around true center");
assert.equal(classicCenterReservation, 340,
    "Classic must mirror the detached 52px secondary plus 8px gap around true center");
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
assert.equal(context.optionalVisibility(859, 260, connectedCenterReservation, 260, 8)
    .showActiveWindow, false,
"a one-pixel-too-narrow Connected output must yield optional edge content");
assert.equal(context.optionalVisibility(860, 260, connectedCenterReservation, 260, 8)
    .showActiveWindow, true,
"the exact Connected collision boundary must retain optional edge content");
assert.equal(context.optionalVisibility(875, 260, classicCenterReservation, 260, 8)
    .showConnectivityDiagnostics, false,
"a one-pixel-too-narrow Classic output must yield optional edge content");
assert.equal(context.optionalVisibility(876, 260, classicCenterReservation, 260, 8)
    .showConnectivityDiagnostics, true,
"the exact Classic collision boundary must retain optional edge content");

const connectedBar = fs.readFileSync(path.join(__dirname, "..", "Titonium", "Bar",
    "Bar.qml"), "utf8");
const classicCenter = fs.readFileSync(path.join(__dirname, "..", "Titonium", "Bar",
    "classic", "ClassicCenterGroup.qml"), "utf8");
assert.match(connectedBar,
    /implicitWidth:\s*BarLayout\.symmetricCenterReservation\(220, 52\)/,
    "Connected Bar must feed the symmetric maximum Center footprint into collision planning");
assert.match(classicCenter,
    /implicitWidth:\s*BarLayout\.symmetricCenterReservation\(220,\s*52 \+ Metrics\.spacingSmall\)/,
    "Classic Bar must reserve the detached secondary pill symmetrically");

console.log("PASS Bar layout and narrow-output collision fixtures");
