#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Bar", "right", "RightPillState.js");
assert.equal(fs.existsSync(rulesPath), true, "RightPillState rules must exist");

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const state = vm.createContext({ Math, Number });
vm.runInContext(source, state, { filename: rulesPath });
const lifecyclePath = path.join(root, "Titonium", "Notifications",
    "NotificationPanelLifecycle.js");
const lifecycleSource = fs.readFileSync(lifecyclePath, "utf8")
    .replace(/^\.pragma library\s*\n/, "");
const lifecycle = vm.createContext({ Object, String });
vm.runInContext(lifecycleSource, lifecycle, { filename: lifecyclePath });
const plain = value => JSON.parse(JSON.stringify(value));

assert.equal(state.normalizeState(false), "compact");
assert.equal(state.normalizeState(true), "menu");
assert.equal(state.menuHeight(300, 900), 332);
assert.equal(state.menuHeight(900, 900), 440);
assert.equal(state.menuHeight(900, 360), 360);
assert.equal(state.menuHeight(900, 100), 100,
    "menu height must not exceed a 100px output");
assert.equal(state.menuHeight(900, 80), 80,
    "menu height must not exceed an 80px output");
assert.equal(state.menuHeight(0, 900), 120);
assert.equal(state.menuWidth(120, 80), 240,
    "short source and menu content keep the minimum usable width");
assert.equal(state.menuWidth(260, 450), 482,
    "dynamic app title expands the menu with horizontal padding");
assert.equal(state.menuWidth(600, 700), 520,
    "dynamic title width remains bounded");
assert.equal(state.contentOpacity(0, "compact"), 1);
assert.equal(state.contentOpacity(1, "compact"), 0);
assert.equal(state.contentOpacity(0, "menu"), 0);
assert.equal(state.contentOpacity(1, "menu"), 1);
assert.equal(state.inputMode(0.2, true), "compact");
assert.equal(state.inputMode(0.5, true), "handoff");
assert.equal(state.inputMode(0.8, true), "menu");
assert.equal(state.shouldDismissTap("left", true, false, false), false,
    "the menu-owning left pill remains interactive");
assert.equal(state.shouldDismissTap("left", false, true, false), true,
    "the opposite right pill dismisses a left menu");
assert.equal(state.shouldDismissTap("right", true, false, false), true,
    "the opposite left pill dismisses a right menu");
assert.equal(state.shouldDismissTap("right", false, true, false), false,
    "the menu-owning right pill remains interactive");
assert.equal(state.shouldDismissTap("left", false, false, true), false,
    "the open branch never dismisses itself");
assert.equal(state.shouldDismissTap("right", false, false, false), true,
    "an outside tap dismisses the menu");

const initialConnected = state.connectedInitialState();
assert.deepEqual(JSON.parse(JSON.stringify(initialConnected)), {
    generation: 0,
    ownerId: "",
    descriptor: null,
    screen: null,
    closing: false,
    closingGeneration: 0,
    focusReturned: false,
});
const notificationOpen = state.connectedOpen(initialConnected,
    "notification-panel:DP-1", {
        ownerId: "notification-panel:DP-1",
        feature: "notifications",
        barConnected: true,
        anchor: "notifications",
        source: "ConnectedNotificationPanelContent.qml",
        invoker: "notification-button",
    }, "DP-1");
assert.equal(notificationOpen.descriptor.feature, "notifications",
    "the connected snapshot must preserve the normalized notification feature");
const notificationMount = lifecycle.transition("",
    notificationOpen.descriptor.feature === "notifications"
        ? notificationOpen.ownerId : "");
assert.deepEqual(plain(notificationMount), {
    mountedOwnerId: "notification-panel:DP-1",
    unmountOwnerId: "",
    mountOwnerId: "notification-panel:DP-1",
    markRead: true,
}, "the adopted notification snapshot must enable the shared mount/read transition");

for (const [feature, anchor, popupSource] of [
    ["network", "network", "ConnectedNetworkPopupContent.qml"],
    ["bluetooth", "bluetooth", "ConnectedBluetoothPopupContent.qml"],
    ["audio", "audio", "ConnectedAudioPopupContent.qml"],
]) {
    const opened = state.connectedOpen(initialConnected, `${feature}:DP-1`, {
        ownerId: `${feature}:DP-1`, feature, barConnected: true, anchor,
        source: popupSource, invoker: `${feature}-button`,
    }, "DP-1");
    assert.equal(opened.descriptor.feature, feature,
        `${feature} must remain valid through the normalized connected snapshot`);
}
const firstConnected = state.connectedOpen(initialConnected, "network:DP-1", {
    barConnected: true,
    anchor: "network",
    source: "ConnectedNetworkPopupContent.qml",
    invoker: "network-button",
}, "DP-1");
assert.equal(firstConnected.generation, 1);
assert.equal(firstConnected.ownerId, "network:DP-1");
assert.equal(firstConnected.closing, false);
assert.equal(state.shouldFinalizeMenuForConnected(true, ""), true,
    "a connected open immediately finalizes the displaced active System Tray menu");
assert.equal(state.shouldFinalizeMenuForConnected(false, "DP-3"), true,
    "a connected open finalizes a displaced System Tray exit on another screen");

const openedDescriptor = {
    barConnected: true,
    anchor: "network",
    source: "ConnectedNetworkPopupContent.qml",
};
const openedScreen = { name: "DP-1" };
assert.equal(state.matchesSurfaceOpen("network:DP-1", openedDescriptor,
    openedScreen, "network:DP-1", openedDescriptor, openedScreen), true,
    "the exact live SurfaceManager presentation may be adopted");
assert.equal(state.matchesSurfaceOpen("", null, null,
    "network:DP-1", openedDescriptor, openedScreen), false,
    "a synchronously rejected open must not be adopted");
assert.equal(state.matchesSurfaceOpen("network:DP-1", { ...openedDescriptor },
    openedScreen, "network:DP-1", openedDescriptor, openedScreen), false,
    "a replacement descriptor with the same owner must reject the stale opened signal");
assert.equal(state.matchesSurfaceOpen("network:DP-1", openedDescriptor,
    { name: "DP-1" }, "network:DP-1", openedDescriptor, openedScreen), false,
    "a replacement screen object must reject the stale opened signal");

const firstClosing = state.connectedRequestClose(firstConnected,
    "network:DP-1", firstConnected.generation);
assert.equal(firstClosing.closing, true);
assert.equal(firstClosing.ownerId, "network:DP-1",
    "close retains ownership until the reverse animation finishes");
assert.equal(firstClosing.descriptor.source, "ConnectedNetworkPopupContent.qml",
    "close retains the Loader source snapshot");
assert.strictEqual(state.connectedFinishClose(firstClosing,
    "network:DP-1", 999), firstClosing,
    "a stale finish generation cannot clear the exiting snapshot");
assert.equal(state.matchesConnectedSnapshot(firstClosing,
    firstClosing.ownerId, firstClosing.generation,
    firstClosing.descriptor, firstClosing.screen), true,
    "Loader failure and screen teardown may release only their exact connected snapshot");

const reopenedConnected = state.connectedOpen(firstClosing, "network:DP-1", {
    barConnected: true,
    anchor: "audio",
    source: "ConnectedAudioPopupContent.qml",
    invoker: "audio-button",
}, "DP-1");
assert.equal(reopenedConnected.generation, 2);
assert.equal(reopenedConnected.closing, false,
    "rapid reopen cancels and reverses the pending close");
assert.equal(reopenedConnected.descriptor.anchor, "audio");
assert.strictEqual(state.connectedFinishClose(reopenedConnected,
    "network:DP-1", firstConnected.generation), reopenedConnected,
    "an old completion cannot clear a newer owner generation");
assert.equal(state.matchesConnectedSnapshot(reopenedConnected,
    firstConnected.ownerId, firstConnected.generation,
    firstConnected.descriptor, firstConnected.screen), false,
    "an old Loader failure cannot release a reopened connected owner");

const reopenedClosing = state.connectedRequestClose(reopenedConnected,
    "network:DP-1", reopenedConnected.generation);
assert.equal(state.canReturnConnectedFocus(reopenedClosing, "network:DP-1",
    reopenedConnected.generation, "network:DP-1", true, false), true,
    "an ordinary close may focus while SurfaceManager retains the exact owner");
assert.equal(state.canReturnConnectedFocus(reopenedClosing, "network:DP-1",
    reopenedConnected.generation, "", false, true), true,
    "an external close may focus the frozen invoker after SurfaceManager releases ownership");
assert.equal(state.canReturnConnectedFocus(reopenedClosing, "network:DP-1",
    reopenedConnected.generation, "audio:DP-1", true, true), false,
    "an external close cannot steal focus from a synchronously opened newer owner");
assert.equal(state.canReturnConnectedFocus(reopenedClosing, "network:DP-1",
    firstConnected.generation, "", false, true), false,
    "a stale close generation cannot focus the frozen invoker");
const focusReturned = state.connectedMarkFocusReturned(reopenedClosing,
    "network:DP-1", reopenedConnected.generation);
assert.equal(focusReturned.focusReturned, true);
assert.equal(state.canReturnConnectedFocus(focusReturned, "network:DP-1",
    reopenedConnected.generation, "", false, true), false,
    "the external close path returns focus at most once per generation");
assert.strictEqual(state.connectedMarkFocusReturned(focusReturned,
    "network:DP-1", reopenedConnected.generation), focusReturned,
    "focus return is recorded exactly once for one owner generation");
const finishedConnected = state.connectedFinishClose(focusReturned,
    "network:DP-1", reopenedConnected.generation);
assert.equal(finishedConnected.ownerId, "");
assert.equal(finishedConnected.generation, reopenedConnected.generation,
    "teardown preserves the monotonic generation counter");

for (const value of [-2, NaN, Infinity]) {
    assert.equal(state.contentOpacity(value, "menu") >= 0, true);
    assert.equal(state.contentOpacity(value, "menu") <= 1, true);
}

console.log("PASS Right Pill state, geometry, content and input rules");
