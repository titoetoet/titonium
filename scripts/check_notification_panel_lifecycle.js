#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Notifications",
    "NotificationPanelLifecycle.js");
assert.equal(fs.existsSync(rulesPath), true,
    "NotificationPanelLifecycle.js must model late Loader assignment");

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const lifecycle = vm.createContext({});
vm.runInContext(source, lifecycle, { filename: rulesPath });
const plain = value => JSON.parse(JSON.stringify(value));

const classicPanelPath = path.join(root, "Titonium", "Notifications",
    "ClassicNotificationPanel.qml");
assert.equal(fs.existsSync(classicPanelPath), true,
    "ClassicNotificationPanel.qml must own detached notification lifecycle");
const classicPanel = fs.readFileSync(classicPanelPath, "utf8");
assert.match(classicPanel, /function\s+finishClose\s*\([\s\S]*?SurfaceManager\.matches\(/,
    "Classic shell must identity-guard close completion");
assert.match(classicPanel, /function\s+reopenIfReplaced\s*\([\s\S]*?panelExit\.stop\(\)/,
    "Classic shell must cancel stale close animation when its descriptor is replaced");
assert.match(classicPanel, /function\s+syncPanelMount\s*\([\s\S]*?NotificationCoordinator\.markAllRead\(\)/,
    "Classic shell must preserve mount-time mark-as-read");
assert.match(classicPanel, /function\s+teardownPanelMount\s*\([\s\S]*?NotificationCoordinator\.panelUnmounted\(/,
    "Classic shell must preserve exact coordinator teardown");

const coordinatorPath = path.join(root, "Titonium", "Services", "Notifications",
    "NotificationCoordinatorRules.js");
const coordinatorSource = fs.readFileSync(coordinatorPath, "utf8")
    .replace(/^\.pragma library\s*\n/, "");
const coordinator = vm.createContext({});
vm.runInContext(coordinatorSource, coordinator, { filename: coordinatorPath });

function applyPlan(state, effect) {
    let next = state;
    if (effect.unmountOwnerId)
        next = coordinator.unmountPanel(next, effect.unmountOwnerId);
    if (effect.mountOwnerId)
        next = coordinator.mountPanel(next, effect.mountOwnerId);
    if (effect.markRead)
        next = coordinator.read(next, "");
    return next;
}

assert.deepEqual(plain(lifecycle.transition("", "")), {
    mountedOwnerId: "", unmountOwnerId: "", mountOwnerId: "", markRead: false,
}, "Component completion before descriptor assignment must have no side effect");

assert.deepEqual(plain(lifecycle.transition("", " notification-panel:DP-1 ")), {
    mountedOwnerId: "notification-panel:DP-1",
    unmountOwnerId: "",
    mountOwnerId: "notification-panel:DP-1",
    markRead: true,
}, "the first valid post-load owner assignment mounts and marks read once");

assert.deepEqual(plain(lifecycle.transition(
    "notification-panel:DP-1", "notification-panel:DP-2")), {
    mountedOwnerId: "notification-panel:DP-2",
    unmountOwnerId: "notification-panel:DP-1",
    mountOwnerId: "notification-panel:DP-2",
    markRead: true,
}, "owner replacement unmounts the exact cached owner before mounting the next");

assert.deepEqual(plain(lifecycle.transition(
    "notification-panel:DP-2", "notification-panel:DP-2")), {
    mountedOwnerId: "notification-panel:DP-2",
    unmountOwnerId: "",
    mountOwnerId: "",
    markRead: false,
}, "repeated descriptor bindings do not remount or mark read");

assert.deepEqual(plain(lifecycle.teardown("notification-panel:DP-2")), {
    mountedOwnerId: "",
    unmountOwnerId: "notification-panel:DP-2",
    mountOwnerId: "",
    markRead: false,
}, "teardown releases the cached owner even after the descriptor disappears");

assert.deepEqual(plain(lifecycle.teardown("")), {
    mountedOwnerId: "", unmountOwnerId: "", mountOwnerId: "", markRead: false,
}, "a Loader error that never mounted has nothing to read or unmount");

const descriptor = Object.freeze({
    key: "native:late-owner", route: "toast", source: "native",
    appId: "fixture.desktop", appName: "Fixture", actions: Object.freeze([]),
});
let coordinatorState = coordinator.publish(
    coordinator.initialState(), descriptor, 10, true, true);
coordinatorState = applyPlan(coordinatorState, lifecycle.transition("", ""));
assert.equal(coordinatorState.panelOpen, false);
assert.deepEqual(plain(coordinatorState.unreadKeys), ["native:late-owner"]);
assert.deepEqual(plain(coordinatorState.toastKeys), ["native:late-owner"]);
const lateMount = lifecycle.transition("", "notification-panel:DP-1");
coordinatorState = applyPlan(coordinatorState, lateMount);
assert.equal(coordinatorState.panelOpen, true);
assert.deepEqual(plain(coordinatorState.unreadKeys), []);
assert.deepEqual(plain(coordinatorState.toastKeys), []);
coordinatorState = applyPlan(coordinatorState,
    lifecycle.teardown(lateMount.mountedOwnerId));
assert.equal(coordinatorState.panelOpen, false);
assert.equal(coordinatorState.panelOwnerId, "");

console.log("PASS late notification panel descriptor assignment and exact teardown lifecycle");
