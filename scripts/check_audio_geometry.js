#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const helperPath = path.join(root, "Titonium/Overlays/Audio/AudioGeometry.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL audio geometry helper is missing");
    process.exit(1);
}
const vm = require("node:vm");
const helperSource = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const geometry = vm.createContext({ Math, Number });
vm.runInContext(helperSource, geometry, { filename: helperPath });
const source = fs.readFileSync(
    path.join(root, "Titonium/Overlays/Audio/ClassicAudioPopupSurface.qml"), "utf8");

function outerHeight(fixedContentHeight, streamHeight, padding, cap) {
    return Math.min(cap, fixedContentHeight + streamHeight + padding * 2);
}

function streamCap(fixedContentHeight, padding, maximumHeight, availableHeight) {
    return Math.max(0,
        Math.min(maximumHeight, availableHeight) - fixedContentHeight - padding * 2);
}

const failures = [];
const fixed = 236;
const stream = 120;
const padding = 16;

if (outerHeight(fixed, stream, padding, 520) !== 388)
    failures.push("outer height must include Panel padding exactly once");
if (streamCap(fixed, padding, 520, 360) !== 92)
    failures.push("stream cap must reserve fixed content and both outer padding edges");
if (outerHeight(fixed, 500, padding, 360) !== 360)
    failures.push("outer height must remain capped by available height");
if (geometry.deviceListHeight(0, 36, 4, 132) !== 0)
    failures.push("empty output-device model must use zero height");
if (geometry.deviceListHeight(1, 36, 4, 132) !== 36)
    failures.push("one output device must instantiate one complete row");
if (geometry.deviceListHeight(5, 36, 4, 132) !== 132)
    failures.push("many output devices must expose a bounded scroll viewport");
if (/ColumnLayout\s*\{[\s\S]*?anchors\.margins\s*:/.test(source))
    failures.push("Audio ColumnLayout must not add margins inside Panel padding");
if (!/fixedContentHeight\s*\+\s*root\.streamHeight\s*\+\s*2\s*\*\s*panel\.padding/.test(source))
    failures.push("panel height must add both Panel padding edges");
if (!/fixedContentHeight\s*-\s*2\s*\*\s*panel\.padding/.test(source))
    failures.push("stream cap must subtract both Panel padding edges");

if (failures.length > 0) {
    console.error("FAIL audio geometry");
    failures.forEach(failure => console.error(failure));
    process.exit(1);
}

console.log("PASS audio geometry");
