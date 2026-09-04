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

function directRowChildren(source, rowId) {
    const idIndex = source.indexOf(`id: ${rowId}`);
    assert.notEqual(idIndex, -1, `missing Row id ${rowId}`);
    const openingBrace = source.lastIndexOf("{", idIndex);
    assert.notEqual(openingBrace, -1, `missing Row opening brace for ${rowId}`);
    assert.match(source.slice(Math.max(0, openingBrace - 16), openingBrace), /Row\s*$/,
        `${rowId} must identify a Row`);

    const children = [];
    let depth = 0;
    for (let index = openingBrace + 1; index < source.length; index++) {
        if (source[index] === "{") {
            if (depth === 0) {
                const type = source.slice(Math.max(openingBrace + 1, index - 96), index)
                    .match(/([A-Za-z_][\w.]*)\s*$/)?.[1];
                assert.ok(type, `${rowId} direct child must have a QML type`);
                children.push({ type, openingBrace: index, source: "" });
            }
            depth++;
        } else if (source[index] === "}") {
            depth--;
            if (depth === 0)
                children.at(-1).source = source.slice(children.at(-1).openingBrace, index + 1);
            if (depth < 0)
                return children;
        }
    }
    assert.fail(`${rowId} Row is not closed`);
}

function assertNotificationBellIsFinalControl(source, relative) {
    const children = directRowChildren(source, "endRow");
    const finalControl = children.at(-1);
    assert.ok(finalControl.type === "NotificationBell"
            || /\bNotificationBell\s*\{/.test(finalControl.source),
    `${relative} must keep NotificationBell as the final direct End-island Row control`);
}

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
    assertNotificationBellIsFinalControl(source, relative);
}

assert.throws(() => assertNotificationBellIsFinalControl(`
    Row {
        id: endRow
        NotificationBell {}
        Item {}
    }
`, "appended-control fixture"),
/final direct End-island Row control/,
"an appended Topbar control must invalidate the rightmost Notification Center contract");

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

const acceptance = read("scripts/notifications_acceptance.sh");
for (const fragment of [
    "WAYLAND_DISPLAY",
    "trigger_notification_control()",
    "hyprctl dispatch global titonium:notifications",
    "panel_matches()",
    'call_ipc audio popup',
    'call_ipc audio popupState',
    'set_runtime_style "classic"',
    'set_runtime_style "connected"',
    '"titonium-edge-menu"',
    '"titonium-overlay"',
]) assert.ok(acceptance.includes(fragment),
    `notification acceptance must exercise the live user route: ${fragment}`);
const fixtureCreationIndex = acceptance.indexOf("test_dir=\"$(mktemp");
const waylandPreflightIndex = acceptance.indexOf('[[ -z "${WAYLAND_DISPLAY:-}"');
const notificationOwnerPreflightIndex = acceptance.indexOf(
    "org.freedesktop.DBus NameHasOwner");
assert.ok(fixtureCreationIndex >= 0, "notification acceptance must create one bounded fixture root");
assert.ok(waylandPreflightIndex >= 0 && waylandPreflightIndex < fixtureCreationIndex,
    "Wayland safe-skip must run before acceptance creates temporary fixture state");
assert.ok(notificationOwnerPreflightIndex >= 0
        && notificationOwnerPreflightIndex < fixtureCreationIndex,
    "notification-owner safe-skip must run before acceptance creates temporary fixture state");
assert.match(acceptance,
    /trigger_notification_control[\s\S]*?wait_for_panel true notification-panel:DP-1 0[\s\S]*?trigger_notification_control[\s\S]*?wait_for_panel false "" 0/,
    "the live shortcut must prove mounted/read then same-control teardown state");
assert.match(acceptance,
    /call_ipc audio popup[\s\S]*?trigger_notification_control[\s\S]*?call_ipc audio popupState/,
    "Connected acceptance must switch from another active Edge owner to notification history");
assert.match(acceptance,
    /set_runtime_style "classic"[\s\S]*?trigger_notification_control[\s\S]*?titonium-overlay/,
    "Classic acceptance must mount history through the detached overlay route");
assert.match(acceptance,
    /set_runtime_style "connected"[\s\S]*?wait_for_panel false "" 0/,
    "a live style transition must tear down the previous notification owner");

const check = read("scripts/check.sh");
assert.match(check,
    /node "\$project_root\/scripts\/check_notification_theme_contract\.js"/,
    "the full static gate must run the themed Notification Center contract");

console.log("PASS themed Notification Center visual and presentation contract");
