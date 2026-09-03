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

assert.equal(state.normalizeState(false), "compact");
assert.equal(state.normalizeState(true), "menu");
assert.equal(state.menuHeight(300, 900), 332);
assert.equal(state.menuHeight(900, 900), 440);
assert.equal(state.menuHeight(900, 360), 360);
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

const reopenedClosing = state.connectedRequestClose(reopenedConnected,
    "network:DP-1", reopenedConnected.generation);
const focusReturned = state.connectedMarkFocusReturned(reopenedClosing,
    "network:DP-1", reopenedConnected.generation);
assert.equal(focusReturned.focusReturned, true);
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
