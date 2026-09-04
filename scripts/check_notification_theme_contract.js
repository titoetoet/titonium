#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");
const loadLibrary = relative => {
    const filename = path.join(root, relative);
    const context = vm.createContext({});
    vm.runInContext(fs.readFileSync(filename, "utf8")
        .replace(/^\.pragma library\s*\n/, ""), context, { filename });
    return context;
};
const plain = value => JSON.parse(JSON.stringify(value));

const presentation = loadLibrary("Titonium/Orchestration/NotificationPanelRouting.js");
assert.deepEqual(plain(presentation.presentation("connected")), {
    owner: "edge",
    source: "ConnectedNotificationPanelContent.qml",
    anchor: "notifications",
}, "Connected history must report the exact right-pill edge presentation");
assert.deepEqual(plain(presentation.presentation("classic")), {
    owner: "overlay",
    source: "ClassicNotificationPanel.qml",
    anchor: "",
}, "Classic history must report the detached overlay presentation");

const topbarControl = read("Titonium/Bar/widgets/NotificationBell.qml");
assert.match(topbarControl, /readonly property string iconName:\s*"history"/,
    "the rightmost Topbar Notification Center control must retain its fixed history glyph");
assert.match(topbarControl, /name:\s*root\.iconName/,
    "the Topbar glyph must be sourced from the fixed history control identity");
assert.doesNotMatch(topbarControl,
    /SequentialAnimation|ParallelAnimation|property:\s*"rotation"|\bwobble\b/,
    "unread changes must not animate the Topbar history glyph");

for (const relative of [
    "Titonium/Bar/islands/EndIsland.qml",
    "Titonium/Bar/classic/ClassicEndIsland.qml",
]) {
    const source = read(relative);
    assert.ok(source.lastIndexOf("NotificationBell {") > source.lastIndexOf("ConnectivityPill {"),
        `${relative} must keep Notification Center as the rightmost Topbar control`);
}

const secondary = read("Titonium/Bar/center/CenterSecondaryPill.qml");
assert.match(secondary, /name:\s*"notifications"/,
    "the Center secondary pill must own the bell glyph");
assert.match(secondary, /id:\s*wobble[\s\S]*?loops:\s*3/,
    "the Center secondary pill must bound bell wobble to three cycles");
assert.match(secondary, /transition\.wobble\s*&&\s*!Motion\.reduced/,
    "Reduced Motion must suppress only the Center secondary-pill wobble");

const classicCenter = read("Titonium/Bar/center/presentations/Classic/ClassicRenderer.qml");
assert.doesNotMatch(classicCenter, /ConnectedPillShape|shoulderSize|bodyWidth\s*:[^\n]*shoulder/,
    "Classic Center must remain a shoulder-free detached surface");

const check = read("scripts/check.sh");
assert.match(check,
    /node "\$project_root\/scripts\/check_notification_theme_contract\.js"/,
    "the full static gate must run the themed Notification Center contract");

console.log("PASS themed Notification Center visual and presentation contract");
