#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");

const file = path.join(__dirname, "..", "Titonium", "Bar", "right", "EdgeMenuGeometry.js");
assert.equal(fs.existsSync(file), true, "EdgeMenuGeometry.js must exist");
const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

assert.deepEqual({...context.branchRect("left", 180, 120, 620, 1920, 420, 240, 0)},
    {x: 180, y: 28, width: 120, height: 8});
assert.deepEqual({...context.branchRect("left", 180, 120, 620, 1920, 420, 240, 1)},
    {x: 30, y: 28, width: 420, height: 212});
assert.deepEqual({...context.branchRect("right", 1850, 36, 220, 1920, 420, 240, 1)},
    {x: 1488, y: 28, width: 420, height: 212});
assert.deepEqual({...context.branchRect("left", 120, 100, 360, 1920, 420, 240, 1)},
    {x: 12, y: 28, width: 420, height: 212});
assert.deepEqual({...context.branchRect("right", 1600, 80, 220, 1920, 420, 240, 1)},
    {x: 1430, y: 28, width: 420, height: 212});
assert.equal(context.branchRect("right", 4, 36, 220, 1920, 420, 240, 1).x, 12);
assert.equal(context.branchRect("left", 180, 120, 620, 1920, 420, 240, 1).x
    + context.branchRect("left", 180, 120, 620, 1920, 420, 240, 1).width / 2, 240);
assert.equal(context.branchRect("right", 1850, 36, 220, 1920, 420, 240, 1).x
    + context.branchRect("right", 1850, 36, 220, 1920, 420, 240, 1).width, 1908,
    "edge-adjacent Input Method menu keeps full width at the output margin");
assert.equal(Object.isFrozen(context.branchRect("left", 0, 0, 0, 0, 0, 0, 1)), true);

const centeredMenu = context.branchRect("left", 180, 120, 620, 1920, 420, 240, 1);
assert.equal(context.sourceOffset(180, 120, centeredMenu, 0), 0,
    "source pill starts at its compact position");
assert.equal(context.sourceOffset(180, 120, centeredMenu, 0.5), 0,
    "already-centered app title stays stationary");
const clampedInputMenu = context.branchRect("right", 1850, 36, 220, 1920, 420, 240, 1);
assert.equal(context.sourceOffset(1850, 36, clampedInputMenu, 0.5), -85,
    "Input Method pill follows halfway toward the clamped menu centre");
assert.equal(context.sourceOffset(1850, 36, clampedInputMenu, 1), -170,
    "Input Method pill ends at the clamped menu centre");

const connectivityControls = [
    {name: "network", x: 1792, width: 28, center: 1806},
    {name: "bluetooth", x: 1824, width: 28, center: 1838},
    {name: "audio", x: 1856, width: 28, center: 1870},
];
assert.deepEqual(connectivityControls.map(control => control.center), [1806, 1838, 1870],
    "three 28px connectivity controls expose distinct source centres");
for (const control of connectivityControls) {
    const branch = context.branchRect("right", control.x, control.width,
        220, 1920, 380, 440, 1);
    assert.deepEqual({...branch}, {x: 1528, y: 28, width: 380, height: 412},
        `${control.name} 380px branch clamps to the 12px output margin`);
}

const leftAnchor = context.anchorSnapshot("left", "DP-1", 96, 4, 260, 28);
assert.equal(Object.isFrozen(leftAnchor), true,
    "Classic descriptors must retain an immutable invoker snapshot");
assert.deepEqual({...leftAnchor}, {
    edge: "left", screenName: "DP-1", x: 96, y: 4, width: 260, height: 28,
});
assert.equal(context.detachedPopupX(leftAnchor, "DP-1", 1920, 380, 12), 36,
    "a left Active Window popup centers beneath its frozen invoker");

const rightAnchor = context.anchorSnapshot("right", "HDMI-A-1", 1836, 4, 28, 28);
assert.equal(context.detachedPopupX(rightAnchor, "HDMI-A-1", 1920, 380, 12), 1528,
    "a right Input popup clamps to its output-local right margin");
assert.equal(context.detachedPopupX(rightAnchor, "DP-1", 1920, 380, 12), 1528,
    "a mismatched output never consumes another output's coordinate snapshot");
assert.equal(context.detachedPopupX(
    context.anchorSnapshot("left", "portrait", 2, 4, 20, 28),
    "portrait", 320, 296, 12), 12,
    "narrow outputs clamp a left invoker without producing a negative popup origin");

console.log("PASS control-anchored edge menu geometry fixtures");
