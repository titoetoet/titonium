#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");
const classicRenderer = read("Titonium/Bar/center/presentations/Classic/ClassicRenderer.qml");
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
    "readonly property alias archHitbox: archSurface",
    "readonly property alias workspaceHitbox: workspaceSurface",
    "readonly property alias activeWindowHitbox: activeWindowSurface",
    "id: archSurface",
    "id: workspaceSurface",
    "id: activeWindowSurface",
    "ArchLogo {",
    "Workspaces {",
    "ActiveWindowPill {",
]);
requireSurfaceCount("Titonium/Bar/classic/ClassicStartIsland.qml", 3);
assert.doesNotMatch(read("Titonium/Bar/classic/ClassicCenterGroup.qml"),
    /CenterIsland|Shared\.Surface|TapHandler|HoverHandler/,
    "Classic Center group is a passive reservation, not another visual owner");
requireFragments("Titonium/Bar/classic/ClassicEndIsland.qml", [
    "readonly property alias notificationHitbox: notificationSurface",
    "readonly property alias pinHitbox: pinSurface",
    "readonly property alias connectivityHitbox: connectivitySurface",
    "readonly property alias statusHitbox: statusSurface",
    "id: notificationSurface",
    "id: pinSurface",
    "id: connectivitySurface",
    "id: statusSurface",
    "NotificationBell {",
    "TopbarPin {",
    "ConnectivityPill {",
    "StatusPill {",
]);
requireSurfaceCount("Titonium/Bar/classic/ClassicEndIsland.qml", 4);
assert.ok(read("Titonium/Bar/classic/ClassicEndIsland.qml").lastIndexOf("NotificationBell {")
    > read("Titonium/Bar/classic/ClassicEndIsland.qml").lastIndexOf("StatusPill {"),
    "Classic Notification Center must be the rightmost surface");
requireFragments("Titonium/Bar/classic/ClassicBar.qml", [
    "readonly property alias archHitbox: startIsland.archHitbox",
    "readonly property alias workspaceHitbox: startIsland.workspaceHitbox",
    "readonly property alias activeWindowHitbox: startIsland.activeWindowHitbox",
    "readonly property alias notificationHitbox: endIsland.notificationHitbox",
    "readonly property alias pinHitbox: endIsland.pinHitbox",
    "readonly property alias connectivityHitbox: endIsland.connectivityHitbox",
    "readonly property alias statusHitbox: endIsland.statusHitbox",
]);
requireSurfaceCount("Titonium/Bar/classic/ClassicBar.qml", 0);

const rulesPath = path.join(root, "Titonium", "Bar", "center", "CenterPresentationRules.js");
const rules = vm.createContext({});
vm.runInContext(fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, ""), rules,
    { filename: rulesPath });
assert.deepEqual(JSON.parse(JSON.stringify(rules.geometry(rules.profile("classic"),
    { width: 1920, height: 1080 }, "compact"))), {
    x: 880, y: 8, width: 160, height: 36, radius: 16,
}, "Classic compact Center geometry must be inset from the top edge");
assert.doesNotMatch(classicRenderer,
    /Connected\.ConnectedRenderer|shoulderSize|bodyWidth\s*:[^\n]*shoulder/,
    "Classic compact Center geometry must not reserve Connected shoulder width");

const surface = read("Titonium/Bar/BarSurface.qml");
assert.match(surface, /active:\s*RightPillCoordinator\.presentedStyle\s*===\s*"connected"/,
    "Connected Bar Loader must be active only in connected mode");
assert.match(surface, /active:\s*RightPillCoordinator\.presentedStyle\s*===\s*"classic"/,
    "Classic Bar Loader must be active only in classic mode");
requireFragments("Titonium/Bar/BarSurface.qml", [
    "readonly property var activeBar:",
    "readonly property var connectedLeftHitbox:",
    "readonly property var connectedRightHitbox:",
    "readonly property var classicArchHitbox:",
    "readonly property var classicWorkspaceHitbox:",
    "readonly property var classicActiveWindowHitbox:",
    "readonly property var classicNotificationHitbox:",
    "readonly property var classicPinHitbox:",
    "readonly property var classicConnectivityHitbox:",
    "readonly property var classicStatusHitbox:",
]);
const expectedMaskItems = [
    "root.connectedLeftHitbox",
    "root.connectedRightHitbox",
    "root.classicArchHitbox",
    "root.classicWorkspaceHitbox",
    "root.classicActiveWindowHitbox",
    "root.classicNotificationHitbox",
    "root.classicPinHitbox",
    "root.classicConnectivityHitbox",
    "root.classicStatusHitbox",
];
for (const item of expectedMaskItems)
    assert.match(surface, new RegExp(`Region \\{ item: ${item.replaceAll(".", "\\.")} \\}`),
        `BarSurface mask must own the exact disjoint ${item} rectangle`);
assert.doesNotMatch(surface, /Region \{ item: root\.(leftHitbox|rightHitbox) \}/,
    "Classic row-group bounds must not swallow the click-through gaps between pills");
requireFragments("Titonium/Bar/BarHost.qml", [
    "profile: CenterPresentationRules.profile(RightPillCoordinator.presentedStyle)",
]);

const barHost = read("Titonium/Bar/BarHost.qml");
assert.equal((barHost.match(/CenterSurfaceHost\s*\{/g) || []).length, 1,
    "all styles share one neutral CenterSurfaceHost owner");
assert.equal(fs.existsSync(path.join(root,
    "Titonium/Bar/classic/ClassicCenterNotchWindow.qml")), false);
assert.equal(fs.existsSync(path.join(root,
    "Titonium/Bar/classic/ClassicCenterNotchSurface.qml")), false);
assert.match(read("Titonium/Bar/islands/ActiveWindowPill.qml"),
    /if \(RightPillCoordinator\.toggleApp\([\s\S]*?return;[\s\S]*?CenterSurfaceController\.dispatch\(\{ type: "request-open",[\s\S]*?mode: "expanded" \}\)/,
    "Active Window without a tray menu must request the shared Center surface");

requireFragments("Titonium/Bar/right/EdgeMenuWindow.qml", [
    "property bool styleActive: true",
    "visible: window.styleActive",
]);

requireFragments("Titonium/Core/Surfaces/Center/CenterOverlayWindow.qml", [
    "window.viewState.focusPolicy === \"exclusive\"",
    "? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None",
    "renderer.visualBounds",
    "CenterSurfaceController.finishClose",
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
assert.match(read("Titonium/Bar/right/EdgeMenuWindow.qml"),
    /onStyleActiveChanged:\s*\{[\s\S]*?if \(window\.styleActive\)[\s\S]*?RightPillCoordinator\.ownerScreenName === window\.screenModel\.name[\s\S]*?RightPillCoordinator\.close\(\);[\s\S]*?RightPillCoordinator\.exitingScreenName === window\.screenModel\.name[\s\S]*?RightPillCoordinator\.finishClose\(window\.screenModel\.name\);/,
    "Classic mode must synchronously clear the matching edge-menu owner and exit state");

console.log("PASS classic bar composition");
