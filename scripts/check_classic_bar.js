#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");
const required = [
    "Titonium/Bar/classic/ClassicBar.qml",
    "Titonium/Bar/classic/ClassicStartIsland.qml",
    "Titonium/Bar/classic/ClassicCenterGroup.qml",
    "Titonium/Bar/classic/ClassicEndIsland.qml",
    "Titonium/Bar/classic/qmldir",
];

for (const file of required)
    assert.equal(fs.existsSync(path.join(root, file)), true, `${file} must exist`);

function requireFragments(relative, fragments) {
    const source = read(relative);
    for (const fragment of fragments)
        assert.ok(source.includes(fragment), `${relative} must contain ${fragment}`);
}

function requireSurfaceCount(relative, expected) {
    const count = (read(relative).match(/Shared\.Surface\s*\{/g) || []).length;
    assert.equal(count, expected, `${relative} must own ${expected} separate Shared.Surface groups`);
}

requireFragments("Titonium/Bar/classic/ClassicStartIsland.qml", [
    "id: archSurface",
    "id: workspaceSurface",
    "id: activeWindowSurface",
    "ArchLogo {",
    "Workspaces {",
    "ActiveWindowPill {",
]);
requireSurfaceCount("Titonium/Bar/classic/ClassicStartIsland.qml", 3);
requireFragments("Titonium/Bar/classic/ClassicCenterGroup.qml", [
    "id: centerSurface",
    "Shared.Surface {",
    "CenterIsland {",
]);
requireSurfaceCount("Titonium/Bar/classic/ClassicCenterGroup.qml", 1);
requireFragments("Titonium/Bar/classic/ClassicEndIsland.qml", [
    "id: pinSurface",
    "id: connectivitySurface",
    "id: statusSurface",
    "TopbarPin {",
    "ConnectivityPill {",
    "StatusPill {",
]);
requireSurfaceCount("Titonium/Bar/classic/ClassicEndIsland.qml", 3);
requireFragments("Titonium/Bar/classic/ClassicBar.qml", [
    "id: notificationSurface",
    "Shared.Surface {",
    "NotificationBell {",
    "readonly property alias leftHitbox: startIsland",
    "readonly property alias centerHitbox: centerGroup",
    "readonly property alias notificationHitbox: notificationSurface",
    "readonly property alias rightHitbox: endIsland",
]);
requireSurfaceCount("Titonium/Bar/classic/ClassicBar.qml", 1);

const surface = read("Titonium/Bar/BarSurface.qml");
assert.match(surface, /active:\s*Preferences\.barStyle\s*===\s*"connected"/,
    "Connected Bar Loader must be active only in connected mode");
assert.match(surface, /active:\s*Preferences\.barStyle\s*===\s*"classic"/,
    "Classic Bar Loader must be active only in classic mode");
requireFragments("Titonium/Bar/BarSurface.qml", [
    "readonly property var activeBar:",
    "root.activeBar ? root.activeBar.leftHitbox : null",
    "root.activeBar && classicBarLoader.active",
    "? root.activeBar.centerHitbox : null",
    "? root.activeBar.notificationHitbox : null",
    "root.activeBar ? root.activeBar.rightHitbox : null",
]);
requireFragments("Titonium/Bar/BarHost.qml", [
    "styleActive: Preferences.barStyle === \"connected\"",
]);

for (const relative of [
    "Titonium/Bar/notch/CenterPillWindow.qml",
    "Titonium/Bar/right/EdgeMenuWindow.qml",
]) {
    requireFragments(relative, [
        "property bool styleActive: true",
        "visible: window.styleActive",
    ]);
}

console.log("PASS classic bar composition");
