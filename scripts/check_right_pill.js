#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const coordinatorPath = path.join(root, "Titonium", "Bar", "right",
    "RightPillCoordinator.qml");
assert.equal(fs.existsSync(coordinatorPath), true, "RightPillCoordinator must exist");
const source = fs.readFileSync(coordinatorPath, "utf8");

for (const fragment of [
    'property string ownerScreenName: ""',
    'property string exitingScreenName: ""',
    'property string activeEdge: ""',
    'property string exitingEdge: ""',
    'property real transitionProgress: root.active ? 1 : 0',
    'readonly property bool active:',
    'function toggleApp(screenName: string, edge: string, appId: string, appName: string): bool',
    'SystemTrayService.prepareAppMenu(appId, appName)',
    'function toggleInput(screenName: string, edge: string): bool',
    'SystemTrayService.prepareInputMenu()',
    'function finishClose(screenName: string): void',
    'SystemTrayService.resetPopupNavigation()',
    'duration: Motion.reduced ? 0 : (root.active ? 240 : 190)',
    'easing.bezierCurve: Motion.springDamped',
    'SystemTrayService.popupPrepared',
]) assert.equal(source.includes(fragment), true, `RightPillCoordinator missing ${fragment}`);

for (const forbidden of ["Loader {", "QsMenuOpener", "Quickshell.Services.SystemTray", "repeat: true", "ChatGPT"])
    assert.equal(source.includes(forbidden), false, `RightPillCoordinator owns forbidden ${forbidden}`);

const service = fs.readFileSync(path.join(root, "Titonium", "Services", "SystemTray",
    "SystemTrayService.qml"), "utf8");
const backend = fs.readFileSync(path.join(root, "Titonium", "Services", "SystemTray",
    "internal", "SystemTrayBackend.qml"), "utf8");
assert.match(service, /readonly property bool popupPrepared:/);
assert.match(backend, /readonly property bool popupPrepared:\s*internal\.popupCurrentMenu !== null/);

const windowPath = path.join(root, "Titonium", "Bar", "right", "EdgeMenuWindow.qml");
const surfacePath = path.join(root, "Titonium", "Bar", "right", "EdgeMenuSurface.qml");
assert.equal(fs.existsSync(windowPath), true, "EdgeMenuWindow must exist");
assert.equal(fs.existsSync(surfacePath), true, "EdgeMenuSurface must exist");
const windowSource = fs.readFileSync(windowPath, "utf8");
const surfaceSource = fs.readFileSync(surfacePath, "utf8");
assert.match(windowSource, /property bool styleActive:\s*true/);
assert.match(windowSource, /visible:\s*window\.styleActive/);
assert.doesNotMatch(windowSource, /Loader\s*\{/);
assert.match(windowSource, /Region \{ item: activeInputRegion \}/);
assert.doesNotMatch(windowSource, /Region \{ item: (left|right)CompactInputRegion \}/,
    "inactive EdgeMenuWindow must pass compact edge clicks to BarSurface");
assert.equal((surfaceSource.match(/Shared\.AnchoredMenuPillShape\s*\{/g) || []).length, 2);
assert.match(surfaceSource, /edge:\s*"left"/);
assert.match(surfaceSource, /edge:\s*"right"/);
assert.match(surfaceSource, /RightPillState\.menuHeight/);
assert.match(surfaceSource, /RightPillState\.menuWidth\(\s*menuView\.implicitContentWidth,\s*root\.leftSourceWidth\)/);
assert.match(surfaceSource, /RightPillState\.menuWidth\(\s*menuView\.implicitContentWidth,\s*root\.rightSourceWidth\)/);
assert.match(surfaceSource, /root\.presentedEdge === "left" \? root\.presentedProgress : 0/);
assert.match(surfaceSource, /root\.presentedEdge === "right" \? root\.presentedProgress : 0/);
assert.match(surfaceSource, /root\.leftMenuBounds\.x \+ root\.leftMenuBounds\.width \+ 16/);
assert.match(surfaceSource, /root\.width - root\.rightMenuBounds\.x \+ 16/);
assert.match(surfaceSource, /root\.presentedEdge !== "left"/);
assert.match(surfaceSource, /root\.presentedEdge !== "right"/);
assert.match(surfaceSource, /compactWidth: root\.presentedLeftCompactWidth/);
assert.match(surfaceSource, /compactX: root\.presentedRightCompactX/);
assert.match(surfaceSource, /SystemTrayMenuView\s*\{/);
assert.doesNotMatch(surfaceSource, /menuOpenedAt|<\s*700/,
    "outside dismissal must not have a post-open dead interval");
assert.match(surfaceSource, /CenterNotchCoordinator\.openExpanded\(root\.screenModel\.name\)/,
    "Center clicks intercepted by an open edge menu must route to Center");
assert.match(surfaceSource, /enabled:\s*root\.ownsMenu && root\.presentedProgress > 0\.7/,
    "outside dismissal must not consume the gesture that opens an edge menu");
assert.match(surfaceSource, /frozenLeftSourceX = root\.liveLeftSourceX/);
assert.match(surfaceSource, /frozenRightSourceX = root\.liveRightSourceX/);
assert.doesNotMatch(surfaceSource,
    /enabled:\s*!root\.ownsMenu \|\| root\.presentedEdge !== "(left|right)"/,
    "opening one menu must not disable every Top Bar control on that edge");
assert.doesNotMatch(surfaceSource, /Shared\.Panel|header/i);

const shapeSource = fs.readFileSync(path.join(root, "Titonium", "Shared",
    "AnchoredMenuPillShape.qml"), "utf8");
assert.equal((shapeSource.match(/ShapePath\s*\{/g) || []).length, 1,
    "pill and branch must share one ShapePath");
assert.equal((shapeSource.match(/\bShape\s*\{/g) || []).length, 1,
    "pill and branch must share one Shape renderer");
assert.doesNotMatch(shapeSource, /Rectangle\s*\{|connector|filler/i);
assert.doesNotMatch(shapeSource, /PathMove\s*\{/,
    "pill and branch must be one closed contour, not overlapping subpaths");
assert.match(shapeSource, /PathSolid \| ShapePath\.PathNonIntersecting/);
assert.match(shapeSource, /readonly property real farSideClearance:/);
assert.match(shapeSource, /root\.farSideClearance/);
assert.match(shapeSource, /readonly property real attachmentRadius:/);
assert.match(shapeSource, /root\.attachmentRadius/);

const endIsland = fs.readFileSync(path.join(root, "Titonium", "Bar", "islands",
    "EndIsland.qml"), "utf8");
const bar = fs.readFileSync(path.join(root, "Titonium", "Bar", "Bar.qml"), "utf8");
const host = fs.readFileSync(path.join(root, "Titonium", "Bar", "BarHost.qml"), "utf8");
assert.doesNotMatch(endIsland, /Shared\.EdgePillShape/);
assert.match(bar, /EndIsland\s*\{/);
assert.match(bar, /StartIsland\s*\{/);
assert.match(bar, /readonly property alias leftHitbox:/);
assert.match(bar, /readonly property alias rightHitbox:/);
assert.match(bar, /RightPillCoordinator\.compactWidth/);
assert.match(host, /EdgeMenuWindow\s*\{/);
assert.doesNotMatch(host, /(Left|Right)PillWindow\s*\{/);

const activeWindow = fs.readFileSync(path.join(root, "Titonium", "Bar", "islands",
    "ActiveWindowPill.qml"), "utf8");
const startIsland = fs.readFileSync(path.join(root, "Titonium", "Bar", "islands",
    "StartIsland.qml"), "utf8");
const inputMethod = fs.readFileSync(path.join(root, "Titonium", "Bar", "widgets",
    "InputMethod.qml"), "utf8");
assert.match(activeWindow, /toggleApp\(\s*root\.screen\.name, "left"/);
assert.match(activeWindow, /menuAnchorX:\s*activityRow\.x \+ activeAppIcon\.x/);
assert.match(activeWindow, /titleLabel\.paintedWidth/);
assert.match(activeWindow, /appNameLabel\.paintedWidth/);
assert.match(activeWindow, /menuAnchorWidth:\s*Math\.max\(1,/);
assert.doesNotMatch(activeWindow, /menuAnchorX:[\s\S]{0,120}titleLabel\.x/,
    "left menu must center on the complete window-title rail");
assert.match(startIsland, /activeWindow\.menuAnchorX/);
assert.match(startIsland, /activeWindow\.menuAnchorWidth/);
assert.match(startIsland, /property real menuAnchorOffset:/);
assert.match(activeWindow, /Translate \{ x: root\.menuAnchorOffset \}/);
assert.match(inputMethod, /toggleInput\(root\.screen\.name, "right"\)/);
assert.match(endIsland, /property real menuAnchorOffset:/);
assert.match(inputMethod, /Translate \{ x: root\.menuAnchorOffset \}/);
assert.match(surfaceSource, /StartIsland\s*\{[\s\S]*?menuAnchorOffset: root\.leftSourceOffset/);
assert.match(surfaceSource, /EndIsland\s*\{[\s\S]*?menuAnchorOffset: root\.rightSourceOffset/);
assert.match(surfaceSource, /StartIsland\s*\{[\s\S]*?z:\s*2/,
    "window-title controls must stay above the overlapping menu clip");
assert.match(surfaceSource, /EndIsland\s*\{[\s\S]*?z:\s*2/,
    "right-side controls must stay above the overlapping menu clip");

console.log("PASS Right Pill coordinator lifecycle and menu preparation contract");
