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

const coordinatorFiles = {
    network: "Titonium/Overlays/Network/NetworkPopupCoordinator.qml",
    bluetooth: "Titonium/Overlays/Bluetooth/BluetoothPopupCoordinator.qml",
    audio: "Titonium/Overlays/Audio/AudioPopupCoordinator.qml",
};

for (const [feature, relative] of Object.entries(coordinatorFiles)) {
    const source = read(relative);
    assert.match(source, /import qs\.Titonium\.Core\.Runtime/,
        `${feature} coordinator must read Preferences.barStyle`);
    assert.match(source, /import qs\.Titonium\.Bar\.right/,
        `${feature} coordinator must use the connected visual-owner API`);
    assert.match(source, /BarPopupRouting\.presentation\(Preferences\.barStyle, feature\)/,
        `${feature} descriptor must use the centralized style route`);
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
}

const bluetoothCoordinator = read(coordinatorFiles.bluetooth);
assert.match(bluetoothCoordinator,
    /function openForIpc[\s\S]*?SurfaceManager\.ownerId === owner[\s\S]*?RightPillCoordinator\.connectedClosing[\s\S]*?RightPillCoordinator\.toggleConnectedSurface\(owner\)/,
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
assert.match(coordinator,
    /BarPopupRouting\.presentation\(Preferences\.barStyle, feature\)/,
    "System Tray routes must use the centralized style selection");
assert.match(coordinator,
    /Qt\.resolvedUrl\("\.\.\/\.\.\/Overlays\/SystemTray\/" \+ route\.source\)/,
    "Classic routes must resolve the centralized detached System Tray source");
assert.match(coordinator,
    /function onBarStyleChanged\(\): void\s*\{[\s\S]*?closeForStyleChange\(\)/,
    "one preference connection must synchronously request style cleanup");
assert.match(coordinator,
    /function closeForStyleChange\(\): void\s*\{[\s\S]*?SurfaceManager\.ownerId[\s\S]*?forceCloseConnectedSurface\(\)[\s\S]*?SurfaceManager\.close\([\s\S]*?CenterNotchCoordinator\.close\(\)[\s\S]*?CenterNotchCoordinator\.finishClose\([\s\S]*?root\.close\(\)[\s\S]*?root\.finishClose\(/,
    "style cleanup must synchronously release the current owner and both visual coordinators");

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

const check = read("scripts/check.sh");
assert.match(check, /node "\$project_root\/scripts\/check_top_bar_style_lifecycle\.js"/,
    "the full static gate must run the Top Bar style lifecycle contract");

console.log("PASS Top Bar style descriptor and lifecycle routing");
