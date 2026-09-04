#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");

const controller = read("Titonium/Core/Surfaces/Center/CenterSurfaceController.qml");
const host = read("Titonium/Core/Surfaces/Center/CenterSurfaceHost.qml");
const compact = read("Titonium/Core/Surfaces/Center/CenterCompactWindow.qml");
const overlay = read("Titonium/Core/Surfaces/Center/CenterOverlayWindow.qml");
const renderer = read("Titonium/Bar/center/CenterRenderer.qml");
const connected = read("Titonium/Bar/center/presentations/Connected/ConnectedRenderer.qml");

assert.match(controller, /readonly property string mode:/);
assert.match(controller, /readonly property string selectedContextId:/);
assert.match(controller, /readonly property var viewState: Object\.freeze\(/);
assert.match(controller, /CenterSurfaceState\.pauseDeadline/);
assert.match(controller, /CenterSurfaceState\.resumeDeadline/);
assert.match(host, /CenterCompactWindow\s*\{/);
assert.match(host, /CenterOverlayWindow\s*\{/);
assert.match(host, /snapshot: CenterDomain\.snapshot/);
assert.match(compact, /WlrLayershell\.keyboardFocus: WlrKeyboardFocus\.None/);
assert.match(compact, /mask: Region \{ Region \{ item: inputRegion \} \}/);
assert.match(compact, /x: renderer\.interactiveBounds\.x/);
assert.match(overlay,
    /window\.viewState\.focusPolicy === "exclusive"[\s\S]*?WlrKeyboardFocus\.Exclusive/);
assert.match(overlay, /CenterSurfaceController\.finishClose\(/);

for (const profile of ["Pill", "Notch", "Connected", "Classic"])
    assert.match(renderer, new RegExp(`${profile}\\.${profile}Renderer`));
assert.match(connected, /required property var snapshot/);
assert.match(connected, /required property var viewState/);
assert.match(connected, /required property var profile/);
assert.match(connected, /signal intentRequested\(var intent\)/);
assert.match(connected, /type: "invoke-action"/);

for (const legacy of [
    "Titonium/Bar/notch/CenterNotchCoordinator.qml",
    "Titonium/Bar/notch/CenterNotchState.js",
    "Titonium/Bar/notch/CenterNotchSurface.qml",
    "Titonium/Bar/notch/CenterNotch.qml",
    "Titonium/Bar/notch/CenterPillWindow.qml",
    "Titonium/Bar/islands/CenterIsland.qml",
]) {
    assert.equal(fs.existsSync(path.join(root, legacy)), false,
        `${legacy} must not survive the neutral Center cutover`);
}

console.log("PASS neutral Center host and renderer integration");
