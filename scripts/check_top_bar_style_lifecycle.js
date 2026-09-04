#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");

function loadLibrary(relative) {
    const filename = path.join(root, relative);
    const source = fs.readFileSync(filename, "utf8")
        .replace(/^\.pragma library\s*\n/, "");
    const context = vm.createContext({ Math, Number, Object, String });
    vm.runInContext(source, context, { filename });
    return context;
}

const routing = loadLibrary("Titonium/Bar/right/BarPopupRouting.js");
const connectedState = loadLibrary("Titonium/Bar/right/RightPillState.js");
const notificationRouting = loadLibrary(
    "Titonium/Orchestration/NotificationPanelRouting.js");

assert.equal(routing.canToggle("audio:DP-1", null, false), true,
    "legacy Audio toggle(screen) must remain a valid request without an invoker");
assert.equal(routing.canToggle("network:DP-1", null, true), false,
    "pointer-only feature toggles may still require their concrete invoker");

assert.equal(routing.existingOpenAction("audio:DP-1", "", false, "", false), "open");
assert.equal(routing.existingOpenAction("audio:DP-1", "audio:DP-1",
    true, "audio:DP-1", false), "preserve",
"an idempotent same-owner IPC open must retain its exact descriptor and invoker");
assert.equal(routing.existingOpenAction("audio:DP-1", "audio:DP-1",
    true, "audio:DP-1", true), "reverse",
"a same-owner IPC open during Connected close must reverse the retained generation");
assert.equal(routing.existingOpenAction("network:DP-1", "network:DP-1",
    false, "", false, false), "preserve",
"an ordinary same-owner Classic IPC open must retain its exact descriptor and invoker");
assert.equal(routing.existingOpenAction("network:DP-1", "network:DP-1",
    false, "", false, true), "replace",
"a same-owner Classic IPC open during exit must replace the closing descriptor");

const styleEvents = [];
let presentedStyle = "connected";
presentedStyle = routing.styleAfterCleanup(presentedStyle, "classic", () => {
    styleEvents.push(`close:${presentedStyle}`);
});
styleEvents.push(`activate:${presentedStyle}`);
assert.deepEqual(styleEvents, ["close:connected", "activate:classic"],
    "style cleanup must finish before the alternate style is published for activation");
presentedStyle = routing.styleAfterCleanup(presentedStyle, "connected", () => {
    styleEvents.push(`close:${presentedStyle}`);
});
assert.equal(presentedStyle, "connected",
    "a Settings preview cancellation must publish the restored effective style");

for (const fixture of [
    ["network", "ConnectedNetworkPopupContent.qml", "ClassicNetworkPopupSurface.qml", "network"],
    ["bluetooth", "ConnectedBluetoothPopupContent.qml", "ClassicBluetoothPopupSurface.qml", "bluetooth"],
    ["audio", "ConnectedAudioPopupContent.qml", "ClassicAudioPopupSurface.qml", "audio"],
]) {
    const [feature, connectedSource, classicSource, anchor] = fixture;
    const connected = routing.presentation("connected", feature);
    const classic = routing.presentation("classic", feature);
    assert.deepEqual(JSON.parse(JSON.stringify({
        source: connected.source,
        feature,
        barConnected: connected.owner === "edge",
        anchor: connected.anchor,
    })), {
        source: connectedSource,
        feature,
        barConnected: true,
        anchor,
    }, `${feature} must select its exact Connected descriptor facts`);
    assert.deepEqual(JSON.parse(JSON.stringify({
        source: classic.source,
        feature,
        barConnected: classic.owner === "edge",
        anchor: classic.anchor,
    })), {
        source: classicSource,
        feature,
        barConnected: false,
        anchor: "",
    }, `${feature} must select its exact Classic descriptor facts`);
}

assert.equal(typeof notificationRouting.presentation, "function",
    "NotificationPanelRouting must expose a pure style presentation rule");
assert.deepEqual(JSON.parse(JSON.stringify(
    notificationRouting.presentation("connected"))), {
    owner: "edge",
    source: "ConnectedNotificationPanelContent.qml",
    anchor: "notifications",
}, "notification history must join the Connected right-pill chassis");
assert.deepEqual(JSON.parse(JSON.stringify(
    notificationRouting.presentation("classic"))), {
    owner: "overlay",
    source: "ClassicNotificationPanel.qml",
    anchor: "",
}, "notification history must remain detached in Classic");

const coordinatorFiles = {
    network: "Titonium/Overlays/Network/NetworkPopupCoordinator.qml",
    bluetooth: "Titonium/Overlays/Bluetooth/BluetoothPopupCoordinator.qml",
    audio: "Titonium/Overlays/Audio/AudioPopupCoordinator.qml",
};

for (const [feature, relative] of Object.entries(coordinatorFiles)) {
    const source = read(relative);
    assert.match(source, /import qs\.Titonium\.Bar\.right/,
        `${feature} coordinator must use the connected visual-owner API`);
    assert.match(source, /BarPopupRouting\.presentation\(RightPillCoordinator\.presentedStyle, feature\)/,
        `${feature} descriptor must use the coordinator-published style`);
    for (const fact of [
        '"source": Qt.resolvedUrl(route.source)',
        '"keyboardFocus": "exclusive"',
        '"closeOnMonitorChange": true',
        '"ownerId": owner',
        '"feature": feature',
        '"barConnected": route.owner === "edge"',
        '"anchor": route.anchor',
        '"invoker": invoker',
    ]) assert.equal(source.includes(fact), true,
        `${feature} descriptor is missing ${fact}`);
    assert.match(source,
        /function toggle[\s\S]*?SurfaceManager\.descriptor\?\.barConnected === true[\s\S]*?RightPillCoordinator\.toggleConnectedSurface\(owner\)/,
        `${feature} same-control Connected toggles must use the reversible owner boundary`);
    assert.match(source,
        /readonly property bool active:[\s\S]*?RightPillCoordinator\.connectedSurfaceActive/,
        `${feature} must report a reversing Connected surface as closed`);
    assert.match(source, /BarPopupRouting\.existingOpenAction\(/,
        `${feature} open must preserve or reverse an exact same-owner presentation`);
    assert.match(source, /SurfaceManager\.isClosing\(owner,[\s\S]*?SurfaceManager\.descriptor,[\s\S]*?SurfaceManager\.screen\)/,
        `${feature} coordinator must distinguish an ordinary Classic open from a closing owner`);
}

for (const relative of [
    "Titonium/Overlays/Network/ClassicNetworkPopupSurface.qml",
    "Titonium/Overlays/Bluetooth/ClassicBluetoothPopupSurface.qml",
    "Titonium/Overlays/Audio/ClassicAudioPopupSurface.qml",
    "Titonium/Overlays/SystemTray/ClassicSystemTrayPopupSurface.qml",
]) {
    const source = read(relative);
    for (const fragment of [
        "property var closingDescriptor: null",
        "property var closingScreen: null",
        "SurfaceManager.beginClose(root.ownerId, root.descriptor, root.screen)",
        "SurfaceManager.closeOwned(root.ownerId, root.closingDescriptor, root.closingScreen)",
        "onDescriptorChanged: root.reopenIfReplaced()",
        "panelExit.stop()",
        "panelEntrance.restart()",
    ]) assert.equal(source.includes(fragment), true,
        `${relative} must provide identity-guarded Classic reopen contract: ${fragment}`);
    assert.doesNotMatch(source, /SurfaceManager\.close\(root\.ownerId\)/,
        `${relative} stale animation completion must never close by owner string alone`);
}

const audioCoordinator = read(coordinatorFiles.audio);
assert.match(audioCoordinator,
    /function toggle\(screen: var, invoker = null\): bool[\s\S]*?BarPopupRouting\.canToggle\(owner, invoker, false\)/,
    "Audio toggle(screen) must remain valid while accepting an optional concrete invoker");

const bluetoothCoordinator = read(coordinatorFiles.bluetooth);
assert.match(bluetoothCoordinator,
    /function openForIpc[\s\S]*?BarPopupRouting\.existingOpenAction\([\s\S]*?action === "reverse"[\s\S]*?RightPillCoordinator\.toggleConnectedSurface\(owner\)/,
    "Bluetooth IPC reopen must reverse a retained same-owner Connected close");

const connectivity = read("Titonium/Bar/islands/ConnectivityPill.qml");
assert.match(connectivity,
    /AudioPopupCoordinator\.toggle\(root\.screen, audioButton\)/,
    "Audio must preserve its exact invoking control in the descriptor");

const activeWindow = read("Titonium/Bar/islands/ActiveWindowPill.qml");
const inputMethod = read("Titonium/Bar/widgets/InputMethod.qml");
assert.match(activeWindow,
    /RightPillCoordinator\.setInvocationContext\(root\.screen, root\);[\s\S]*?RightPillCoordinator\.toggleApp\([\s\S]*?root\.screen\.name, "left",[\s\S]*?root\.appName\)/,
    "Active Window routing must preserve the exact screen and invoking control");
assert.match(inputMethod,
    /RightPillCoordinator\.setInvocationContext\(root\.screen, root\);[\s\S]*?RightPillCoordinator\.toggleInput\(root\.screen\.name, "right"\)/,
    "Input Method routing must preserve the exact screen and invoking control");

const coordinator = read("Titonium/Bar/right/RightPillCoordinator.qml");
const surfaceRouter = read("Titonium/Orchestration/SurfaceRouter.qml");
assert.match(coordinator,
    /BarPopupRouting\.presentation\(root\.presentedStyle, feature\)/,
    "System Tray routes must use the centralized style selection");
assert.match(coordinator,
    /Qt\.resolvedUrl\("\.\.\/\.\.\/Overlays\/SystemTray\/" \+ route\.source\)/,
    "Classic routes must resolve the centralized detached System Tray source");
assert.match(coordinator,
    /property string presentedStyle:\s*""/,
    "the coordinator must begin with no alternate tree published");
assert.match(coordinator,
    /Component\.onCompleted:\s*root\.presentedStyle =\s*BarPopupRouting\.normalizeStyle\(Preferences\.barStyle\)/,
    "the coordinator must publish its initial effective style as a one-shot value");
assert.doesNotMatch(coordinator,
    /property string presentedStyle:[^\n]*Preferences\.barStyle/,
    "presented style must not be a raw preference binding that can activate before cleanup");
assert.match(coordinator,
    /function onBarStyleChanged\(\): void\s*\{[\s\S]*?root\.presentedStyle = BarPopupRouting\.styleAfterCleanup\([\s\S]*?root\.closeForStyleChange\(\)/,
    "one preference connection must clean up before publishing the alternate style");
assert.match(coordinator,
    /function closeForStyleChange\(\): void\s*\{[\s\S]*?SurfaceManager\.descriptor[\s\S]*?SurfaceManager\.screen[\s\S]*?forceCloseConnectedSurface\(\)[\s\S]*?RightPillState\.matchesSurfaceOpen\([\s\S]*?SurfaceManager\.close\([\s\S]*?CenterSurfaceController\.dispatch\(\{ type: "request-mode", mode: "compact" \}\)[\s\S]*?root\.close\(\)[\s\S]*?root\.finishClose\(/,
    "style cleanup must release the current owner and compact the neutral Center surface");
assert.match(surfaceRouter,
    /function toggleNotificationPanel[\s\S]*?NotificationPanelRouting\.presentation\(RightPillCoordinator\.presentedStyle\)[\s\S]*?BarPopupRouting\.existingOpenAction\([\s\S]*?action === "reverse"[\s\S]*?RightPillCoordinator\.toggleConnectedSurface\(owner\)/,
    "Notification routing must reverse a retained same-owner Connected close");
assert.match(surfaceRouter,
    /function toggleNotificationPanel[\s\S]*?action === "preserve"[\s\S]*?route\.owner === "edge"[\s\S]*?RightPillCoordinator\.toggleConnectedSurface\(owner\)[\s\S]*?SurfaceManager\.close\(owner\)/,
    "same-owner Notification toggles must close through the style's owning coordinator");

const barSurface = read("Titonium/Bar/BarSurface.qml");
const barHost = read("Titonium/Bar/BarHost.qml");
assert.doesNotMatch(barSurface, /active:\s*Preferences\.barStyle/,
    "Bar Loaders must not activate directly from an uncleaned preference change");
assert.match(barSurface,
    /active:\s*RightPillCoordinator\.presentedStyle === "connected"/);
assert.match(barSurface,
    /active:\s*RightPillCoordinator\.presentedStyle === "classic"/);
assert.doesNotMatch(barHost, /styleActive:\s*Preferences\.barStyle/,
    "connected visual windows must not activate directly from Preferences");
assert.equal((barHost.match(
    /styleActive:\s*RightPillCoordinator\.presentedStyle === "connected"/g) || []).length, 1);
assert.match(barHost, /CenterSurfaceHost\s*\{[\s\S]*?profile:\s*CenterPresentationRules\.profile\(RightPillCoordinator\.presentedStyle\)/,
    "one Center owner receives the published style as presentation data");

const initial = connectedState.connectedInitialState();
const first = connectedState.connectedOpen(initial, "network:DP-1", {
    ownerId: "network:DP-1",
    source: "ConnectedNetworkPopupContent.qml",
    feature: "network",
    barConnected: true,
    anchor: "network",
    invoker: "network-button",
}, "DP-1");
const closing = connectedState.connectedRequestClose(first,
    first.ownerId, first.generation);
const newer = connectedState.connectedOpen(closing, "audio:DP-1", {
    ownerId: "audio:DP-1",
    source: "ConnectedAudioPopupContent.qml",
    feature: "audio",
    barConnected: true,
    anchor: "audio",
    invoker: "audio-button",
}, "DP-1");
assert.strictEqual(connectedState.connectedFinishClose(newer,
    first.ownerId, first.generation), newer,
"a stale owner/generation completion must not clear a newer style owner");
assert.strictEqual(connectedState.connectedClear(newer,
    first.ownerId, first.generation), newer,
"a stale style-shutdown generation must not clear a newer style owner");

const capturedDescriptor = { source: "ConnectedAudioPopupContent.qml" };
const replacementDescriptor = { source: "ConnectedAudioPopupContent.qml" };
const capturedScreen = { name: "DP-1" };
assert.equal(connectedState.matchesSurfaceOpen("audio:DP-1", replacementDescriptor,
    capturedScreen, "audio:DP-1", capturedDescriptor, capturedScreen), false,
"a synchronous same-owner reopen must fail the stale descriptor identity guard");

const notificationDescriptor = {
    ownerId: "notification-panel:DP-1",
    source: "ConnectedNotificationPanelContent.qml",
    feature: "notifications",
    barConnected: true,
    anchor: "notifications",
    invoker: "notification-button",
};
const notificationOpen = connectedState.connectedOpen(
    connectedState.connectedInitialState(), notificationDescriptor.ownerId,
    notificationDescriptor, capturedScreen);
const notificationClosing = connectedState.connectedRequestClose(notificationOpen,
    notificationOpen.ownerId, notificationOpen.generation);
const notificationReleased = connectedState.connectedClear(notificationClosing,
    notificationClosing.ownerId, notificationClosing.generation);
assert.strictEqual(connectedState.connectedFinishClose(notificationReleased,
    notificationClosing.ownerId, notificationClosing.generation), notificationReleased,
    "a stale Connected notification close cannot clear a subsequently opened Classic owner");

const check = read("scripts/check.sh");
assert.match(check, /node "\$project_root\/scripts\/check_top_bar_style_lifecycle\.js"/,
    "the full static gate must run the Top Bar style lifecycle contract");

console.log("PASS Top Bar style descriptor and lifecycle routing");
