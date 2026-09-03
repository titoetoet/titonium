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
assert.match(surface, /active:\s*RightPillCoordinator\.presentedStyle\s*===\s*"connected"/,
    "Connected Bar Loader must be active only in connected mode");
assert.match(surface, /active:\s*RightPillCoordinator\.presentedStyle\s*===\s*"classic"/,
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
    "styleActive: RightPillCoordinator.presentedStyle === \"connected\"",
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

requireFragments("Titonium/Bar/notch/CenterPillWindow.qml", [
    "WlrLayershell.keyboardFocus: window.ownsIsland",
    "? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None",
    "visible: window.styleActive && !window.ownsIsland && !window.dismissing",
    "width: window.styleActive && !window.ownsIsland ? surface.compactInputWidth : 0",
    "height: window.styleActive && !window.ownsIsland ? surface.compactInputHeight : 0",
    "CenterNotchCoordinator.ownerScreenName === window.screenModel.name",
    "CenterNotchCoordinator.collapse();",
    "CenterNotchCoordinator.exitingScreenName === window.screenModel.name",
    "CenterNotchCoordinator.finishClose(window.screenModel.name);",
]);
requireFragments("Titonium/Bar/right/EdgeMenuWindow.qml", [
    "WlrLayershell.keyboardFocus: window.ownsMenu",
    "? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None",
    "width: window.ownsMenu ? window.width : 0",
    "RightPillCoordinator.ownerScreenName === window.screenModel.name",
    "RightPillCoordinator.close();",
    "RightPillCoordinator.exitingScreenName === window.screenModel.name",
    "RightPillCoordinator.finishClose(window.screenModel.name);",
]);
assert.match(read("Titonium/Bar/notch/CenterPillWindow.qml"),
    /onStyleActiveChanged:\s*\{[\s\S]*?if \(window\.styleActive\)[\s\S]*?CenterNotchCoordinator\.ownerScreenName === window\.screenModel\.name[\s\S]*?CenterNotchCoordinator\.collapse\(\);[\s\S]*?CenterNotchCoordinator\.exitingScreenName === window\.screenModel\.name[\s\S]*?CenterNotchCoordinator\.finishClose\(window\.screenModel\.name\);/,
    "Classic mode must synchronously clear the matching Center owner and exit state");
assert.match(read("Titonium/Bar/right/EdgeMenuWindow.qml"),
    /onStyleActiveChanged:\s*\{[\s\S]*?if \(window\.styleActive\)[\s\S]*?RightPillCoordinator\.ownerScreenName === window\.screenModel\.name[\s\S]*?RightPillCoordinator\.close\(\);[\s\S]*?RightPillCoordinator\.exitingScreenName === window\.screenModel\.name[\s\S]*?RightPillCoordinator\.finishClose\(window\.screenModel\.name\);/,
    "Classic mode must synchronously clear the matching edge-menu owner and exit state");

console.log("PASS classic bar composition");
