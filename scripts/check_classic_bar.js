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
    "Titonium/Bar/classic/ClassicCenterNotchWindow.qml",
    "Titonium/Bar/classic/ClassicCenterNotchSurface.qml",
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
requireFragments("Titonium/Bar/classic/ClassicCenterGroup.qml", [
    "readonly property alias centerHitbox: centerSurface",
    "id: centerSurface",
    "Shared.Surface {",
    "CenterIsland {",
]);
requireSurfaceCount("Titonium/Bar/classic/ClassicCenterGroup.qml", 1);
requireFragments("Titonium/Bar/classic/ClassicEndIsland.qml", [
    "readonly property alias pinHitbox: pinSurface",
    "readonly property alias connectivityHitbox: connectivitySurface",
    "readonly property alias statusHitbox: statusSurface",
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
    "readonly property alias archHitbox: startIsland.archHitbox",
    "readonly property alias workspaceHitbox: startIsland.workspaceHitbox",
    "readonly property alias activeWindowHitbox: startIsland.activeWindowHitbox",
    "readonly property alias centerHitbox: centerGroup.centerHitbox",
    "readonly property alias notificationHitbox: notificationSurface",
    "readonly property alias pinHitbox: endIsland.pinHitbox",
    "readonly property alias connectivityHitbox: endIsland.connectivityHitbox",
    "readonly property alias statusHitbox: endIsland.statusHitbox",
]);
requireSurfaceCount("Titonium/Bar/classic/ClassicBar.qml", 1);

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
    "readonly property var classicCenterHitbox:",
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
    "root.classicCenterHitbox",
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
    "styleActive: RightPillCoordinator.presentedStyle === \"connected\"",
    "ClassicCenterNotchWindow {",
    "styleActive: RightPillCoordinator.presentedStyle === \"classic\"",
]);

const barHost = read("Titonium/Bar/BarHost.qml");
assert.equal((barHost.match(/CenterPillWindow\s*\{/g) || []).length, 1,
    "only the Connected owner may instantiate CenterPillWindow");
assert.equal((barHost.match(/ClassicCenterNotchWindow\s*\{/g) || []).length, 1,
    "Classic must have one detached center owner per output variant");

requireFragments("Titonium/Bar/classic/ClassicCenterNotchWindow.qml", [
    "PanelWindow {",
    "property bool styleActive: true",
    "CenterNotchCoordinator.ownerScreenName === window.screenModel.name",
    "visible: window.styleActive && (window.ownsNotch || window.dismissing)",
    "WlrLayershell.namespace: \"titonium-classic-center-notch\"",
    "ClassicCenterNotchSurface {",
    "CenterNotchCoordinator.finishClose(window.screenModel.name)",
]);
requireFragments("Titonium/Bar/classic/ClassicCenterNotchSurface.qml", [
    "Shared.Panel {",
    "CenterNotch {",
    "readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing",
    "anchors.horizontalCenter: parent.horizontalCenter",
    "onFinished: root.closeAnimationFinished()",
    "CenterNotchCoordinator.collapse()",
]);
for (const forbidden of ["NotificationNative", "MprisNative", "WeatherNative", "FileView", "Process"])
    assert.equal(read("Titonium/Bar/classic/ClassicCenterNotchSurface.qml").includes(forbidden), false,
        `Classic center must not restore retired service ownership: ${forbidden}`);
assert.match(read("Titonium/Bar/islands/ActiveWindowPill.qml"),
    /if \(RightPillCoordinator\.toggleApp\([\s\S]*?return;[\s\S]*?CenterNotchCoordinator\.openExpanded\(root\.screen\.name\)/,
    "Active Window without a tray menu must open the shared coordinator for the Classic owner");
assert.match(read("Titonium/Bar/widgets/NotificationBell.qml"),
    /CenterNotchCoordinator\.openBanner\(root\.screen\.name,/,
    "the Classic notification bell must route its banner through the shared coordinator");
assert.match(read("Titonium/Bar/notch/CenterPillWindow.qml"),
    /readonly property bool ownsIsland: window\.styleActive[\s\S]*?CenterNotchCoordinator\.ownerScreenName/,
    "a disabled Connected Center window can never become the Classic visual owner");
assert.match(read("Titonium/Bar/classic/ClassicCenterNotchWindow.qml"),
    /readonly property bool ownsNotch: window\.styleActive[\s\S]*?CenterNotchCoordinator\.ownerScreenName/,
    "the detached Classic window must be the only active Classic center owner");

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
