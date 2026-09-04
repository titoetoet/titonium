#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Orchestration", "NotificationPanelRouting.js");
assert.equal(fs.existsSync(rulesPath), true, "NotificationPanelRouting rules must exist");

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const routing = vm.createContext({});
vm.runInContext(source, routing, { filename: rulesPath });
const plain = value => JSON.parse(JSON.stringify(value));
const loadLibrary = relative => {
    const filename = path.join(root, relative);
    const context = vm.createContext({ Math, Number, Object, String });
    vm.runInContext(fs.readFileSync(filename, "utf8")
        .replace(/^\.pragma library\s*\n/, ""), context, { filename });
    return context;
};
const barRouting = loadLibrary("Titonium/Bar/right/BarPopupRouting.js");
const rightPillState = loadLibrary("Titonium/Bar/right/RightPillState.js");

assert.equal(routing.ownerId("DP-1"), "notification-panel:DP-1");
assert.equal(routing.ownerId("  DP-2  "), "notification-panel:DP-2");
assert.equal(routing.ownerId(""), "");
assert.equal(routing.toggleAction("", "notification-panel:DP-1"), "open");
assert.equal(routing.toggleAction("spotlight:DP-1", "notification-panel:DP-1"), "replace");
assert.equal(routing.toggleAction("notification-panel:DP-1",
    "notification-panel:DP-2"), "replace");
assert.equal(routing.toggleAction("notification-panel:DP-1",
    "notification-panel:DP-1"), "close");
assert.equal(routing.toggleAction("notification-panel:DP-1", ""), "reject");

assert.equal(typeof routing.presentation, "function",
    "NotificationPanelRouting must expose a pure style presentation rule");
assert.deepEqual(plain(routing.presentation("connected")), {
    owner: "edge",
    source: "ConnectedNotificationPanelContent.qml",
    anchor: "notifications",
}, "Connected Notification Center must route through the exact right-pill control");
assert.deepEqual(plain(routing.presentation("classic")), {
    owner: "overlay",
    source: "ClassicNotificationPanel.qml",
    anchor: "",
}, "Classic Notification Center must retain its detached overlay");
assert.deepEqual(plain(routing.presentation("unknown")), {
    owner: "edge",
    source: "ConnectedNotificationPanelContent.qml",
    anchor: "notifications",
}, "unknown style values must fail closed to the shipped Connected presentation");

const screen = { name: "DP-1" };
const notificationOwner = "notification-panel:DP-1";
const notificationDescriptor = {
    ownerId: notificationOwner,
    source: "ConnectedNotificationPanelContent.qml",
    feature: "notifications",
    barConnected: true,
    anchor: "notifications",
    invoker: "notification-control",
};
const notificationOpen = rightPillState.connectedOpen(
    rightPillState.connectedInitialState(), notificationOwner,
    notificationDescriptor, screen);
assert.equal(barRouting.existingOpenAction(notificationOwner, notificationOwner,
    true, notificationOwner, false, false), "preserve",
"the active Edge copy of the same notification control must select the guarded close path");
const notificationClosing = rightPillState.connectedRequestClose(notificationOpen,
    notificationOwner, notificationOpen.generation);
assert.equal(notificationClosing.closing, true);
assert.equal(notificationClosing.closingGeneration, notificationOpen.generation,
    "same-control close must retain the owner generation until teardown");
assert.equal(rightPillState.canReturnConnectedFocus(notificationClosing,
    notificationOwner, notificationOpen.generation,
    notificationOwner, true, false), true,
"same-control close must preserve the exact-owner focus-return guard");

assert.equal(barRouting.existingOpenAction(notificationOwner, "", false, "", false, false),
    "open", "a notification request from an active legacy Edge menu must open history");
assert.equal(rightPillState.shouldFinalizeMenuForConnected(false, "DP-1"), true,
    "adopting notification history must finalize the displaced Edge-menu exit");

const audioOwner = "audio:DP-1";
const audioOpen = rightPillState.connectedOpen(rightPillState.connectedInitialState(),
    audioOwner, {
        ownerId: audioOwner,
        source: "ConnectedAudioPopupContent.qml",
        feature: "audio",
        barConnected: true,
        anchor: "audio",
        invoker: "audio-control",
    }, screen);
assert.equal(barRouting.existingOpenAction(notificationOwner, audioOwner,
    true, audioOwner, false, false), "open",
"a notification request from another active connected surface must replace that control");
const notificationReplacement = rightPillState.connectedOpen(audioOpen,
    notificationOwner, notificationDescriptor, screen);
assert.deepEqual([
    notificationReplacement.ownerId,
    notificationReplacement.descriptor.feature,
    notificationReplacement.generation > audioOpen.generation,
], [notificationOwner, "notifications", true],
"cross-control replacement must adopt notification history as a newer owner generation");
assert.strictEqual(rightPillState.connectedFinishClose(notificationReplacement,
    audioOwner, audioOpen.generation), notificationReplacement,
"a displaced control's stale completion must not clear notification history");

console.log("PASS style-aware notification panel and screen-owner routing");
