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
    'readonly property bool presentationActive: root.menuActive || root.connectedSurfaceActive',
    'property real transitionProgress: root.presentationActive ? 1 : 0',
    'readonly property bool active:',
    'function toggleApp(screenName: string, edge: string, appId: string, appName: string): bool',
    'SystemTrayService.prepareAppMenu(appId, appName)',
    'function toggleInput(screenName: string, edge: string): bool',
    'SystemTrayService.prepareInputMenu()',
    'function finishClose(screenName: string): void',
    'SystemTrayService.resetPopupNavigation()',
    'duration: Motion.reduced ? 0 : (root.presentationActive ? 240 : 190)',
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
assert.match(windowSource,
    /SurfaceManager\.descriptor\?\.barConnected === true[\s\S]*?SurfaceManager\.screen === window\.screenModel/,
    "EdgeMenuWindow must own connected descriptors for its screen");
assert.match(windowSource, /WlrLayershell\.keyboardFocus:\s*window\.ownsMenu/,
    "connected descriptors must focus only the Edge window");
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
assert.equal((surfaceSource.match(/\bLoader\s*\{/g) || []).length, 1,
    "EdgeMenuSurface must own one connected-content Loader");
assert.match(surfaceSource,
    /SurfaceManager\.descriptor\?\.barConnected === true[\s\S]*?SurfaceManager\.screen === root\.screenModel/,
    "EdgeMenuSurface must select only its screen-local connected descriptor");
assert.match(surfaceSource, /SurfaceManager\.descriptor\?\.anchor/,
    "connected branch geometry must select the descriptor anchor");
assert.match(surfaceSource, /rightContent\.connectivityAnchorRect\(/,
    "connected branch geometry must consume the EndIsland anchor");
assert.match(surfaceSource,
    /function onOpened\([\s\S]*?descriptor\?\.barConnected === true[\s\S]*?root\.freezeRightAnchor\(\)/,
    "every connected descriptor open must freeze its selected right anchor");
assert.match(surfaceSource, /source:\s*active \? SurfaceManager\.descriptor\.source : ""/,
    "Edge Loader source must come from the connected descriptor");
assert.match(surfaceSource, /property:\s*"availableViewportHeight"[\s\S]*?value:\s*menuClip\.height/,
    "Connected Audio viewport must bind to the branch viewport");
assert.match(surfaceSource, /onDismissRequested[\s\S]*?root\.closePresentedMenu\(\)/,
    "connected content dismissal must use the shared close intent");
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
const connectivityPill = fs.readFileSync(path.join(root, "Titonium", "Bar", "islands",
    "ConnectivityPill.qml"), "utf8");
const bar = fs.readFileSync(path.join(root, "Titonium", "Bar", "Bar.qml"), "utf8");
const host = fs.readFileSync(path.join(root, "Titonium", "Bar", "BarHost.qml"), "utf8");
assert.doesNotMatch(endIsland, /Shared\.EdgePillShape/);
assert.match(connectivityPill, /function anchorRect\(name: string\): rect/);
for (const [name, button] of [
    ["network", "networkButton"],
    ["bluetooth", "bluetoothButton"],
    ["audio", "audioButton"],
]) assert.match(connectivityPill, new RegExp(`name === "${name}"[\\s\\S]*?${button}`),
    `ConnectivityPill must map ${name} to ${button}`);
assert.match(connectivityPill,
    /Qt\.rect\(iconRow\.x \+ item\.x, iconRow\.y \+ item\.y, item\.width, item\.height\)/);
assert.match(endIsland, /function connectivityAnchorRect\(name: string\): rect/);
assert.match(endIsland, /connectivity\.anchorRect\(name\)/);
assert.match(endIsland, /connectivity\.mapToItem\(root,/,
    "EndIsland must convert connectivity anchors into its own coordinates");
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
assert.match(surfaceSource,
    /EndIsland\s*\{[\s\S]*?menuAnchorOffset: root\.ownsConnectedSurface \? 0\s*:\s*root\.rightSourceOffset/,
    "connectivity popups must keep unrelated EndIsland controls stationary");
assert.match(surfaceSource, /StartIsland\s*\{[\s\S]*?z:\s*2/,
    "window-title controls must stay above the overlapping menu clip");
assert.match(surfaceSource, /EndIsland\s*\{[\s\S]*?z:\s*2/,
    "right-side controls must stay above the overlapping menu clip");

assert.match(source, /import qs\.Titonium\.Core\.Surfaces/);
assert.match(source, /readonly property bool connectedSurfaceActive:/);
assert.match(source, /SurfaceManager\.descriptor\?\.barConnected === true/);
assert.match(source, /if \(!root\.connectedSurfaceActive\)[\s\S]*?SurfaceManager\.close\(SurfaceManager\.ownerId\)/,
    "RightPillCoordinator close must delegate connected lifecycle to SurfaceManager");
assert.match(source, /if \(root\.menuActive && !SystemTrayService\.popupPrepared\)/,
    "System Tray validity must not close Network, Bluetooth, or Audio descriptors");

const classicPopupPath = path.join(root, "Titonium", "Overlays", "SystemTray",
    "ClassicSystemTrayPopupSurface.qml");
assert.equal(fs.existsSync(classicPopupPath), true, "Classic System Tray popup must exist");
const classicPopupSource = fs.readFileSync(classicPopupPath, "utf8");
for (const fragment of [
    "property var descriptor:", "property var screen:", "Shared.Panel", "SurfaceManager.close",
    "Keys.onEscapePressed", "TapHandler {", "anchors.fill: parent",
    "readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing",
    "anchors.rightMargin: Metrics.barPadding", "width: 380", "SystemTrayMenuView {",
    "SystemTrayService.popupEntries", "SystemTrayService.resetPopupNavigation()",
    "property bool closing: false", "property bool navigationReset: false",
    "function resetNavigation(): void", "function finishClose(): void", "if (root.closing)",
    "if (Motion.reduced)", "panelExit.restart()", "transformOrigin: Item.Top",
    "opacity: Motion.reduced ? 1 : 0", "scale: Motion.reduced ? 1 : 0.94",
    "transform: Translate {", "id: panelEntranceOffset", "id: panelEntrance",
    "running: !Motion.reduced", "id: panelExit", "onFinished: root.finishClose()",
    "Component.onDestruction: root.resetNavigation()",
]) assert.equal(classicPopupSource.includes(fragment), true,
    `Classic System Tray popup missing ${fragment}`);
assert.equal((classicPopupSource.match(/SurfaceManager\.close\(root\.ownerId\)/g) || []).length, 1,
    "Classic System Tray popup must close SurfaceManager exactly once through teardown");
assert.equal((classicPopupSource.match(/SystemTrayService\.resetPopupNavigation\(\)/g) || []).length, 1,
    "Classic System Tray navigation must reset exactly once through guarded teardown");
for (const forbidden of ["QsMenuOpener", "Quickshell.Services.SystemTray", "Process", "FileView"])
    assert.equal(classicPopupSource.includes(forbidden), false,
        `Classic System Tray popup owns forbidden ${forbidden}`);

const trayQmldir = fs.readFileSync(path.join(root, "Titonium", "Overlays", "SystemTray", "qmldir"), "utf8");
assert.match(trayQmldir, /ClassicSystemTrayPopupSurface 1\.0 ClassicSystemTrayPopupSurface\.qml/);

console.log("PASS Right Pill coordinator lifecycle and menu preparation contract");
