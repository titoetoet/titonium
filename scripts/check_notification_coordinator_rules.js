#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Notifications",
    "NotificationCoordinatorRules.js");

assert.equal(fs.existsSync(rulesPath), true,
    "NotificationCoordinatorRules.js must exist for unified notification state");

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

const notificationRulesPath = path.join(root, "Titonium", "Services", "Notifications",
    "NotificationRules.js");
const notificationRules = vm.createContext({});
vm.runInContext(fs.readFileSync(notificationRulesPath, "utf8")
    .replace(/^\.pragma library\s*\n/, ""), notificationRules,
{ filename: notificationRulesPath });

const centerRulesPath = path.join(root, "Titonium", "Services", "Center", "adapters",
    "NotificationCenterRules.js");
const centerRules = vm.createContext({ encodeURIComponent, decodeURIComponent });
vm.runInContext(fs.readFileSync(centerRulesPath, "utf8")
    .replace(/^\.pragma library\s*\n/, ""), centerRules,
{ filename: centerRulesPath });

const plain = value => JSON.parse(JSON.stringify(value));

function item(key, route, receivedAt, overrides = {}) {
    return Object.freeze(Object.assign({
        key,
        source: key.startsWith("native:") ? "native" : "internal",
        appId: key.startsWith("native:") ? "fixture.desktop" : "",
        appName: "Fixture",
        appIcon: "notifications",
        summary: key,
        body: "",
        urgency: route === "center" ? 2 : 1,
        nativeUrgency: route === "center" ? "critical" : "normal",
        severity: route === "center" ? "critical" : "normal",
        route,
        category: key.startsWith("internal:timer") ? "timer" : "notification",
        actions: Object.freeze([]),
        receivedAt,
    }, overrides));
}

let state = rules.initialState();
assert.equal(state.panelOpen, false);
assert.equal(state.panelOwnerId, "");
state = rules.publish(state, item("native:1", "toast", 100), 100, true, true);
state = rules.publish(state, item("native:2", "history", 200), 200, true, true);
assert.deepEqual(plain(state.history.map(entry => entry.key)), ["native:2", "native:1"]);
assert.deepEqual(plain(state.unreadKeys), ["native:2", "native:1"]);
assert.deepEqual(plain(state.toastKeys), ["native:1"]);
assert.equal(state.currentCritical, null);
assert.equal(Object.isFrozen(state), true);
assert.equal(Object.isFrozen(state.history), true);
assert.equal(Object.isFrozen(state.unreadKeys), true);
console.log("PASS passive notifications enter immutable history without false critical state");

let panelState = rules.publish(rules.initialState(),
    item("native:panel-before", "toast", 10), 10, true, true);
panelState = rules.mountPanel(panelState, "notification-panel:DP-1");
assert.equal(panelState.panelOpen, true);
assert.equal(panelState.panelOwnerId, "notification-panel:DP-1");
assert.deepEqual(plain(panelState.unreadKeys), ["native:panel-before"]);
panelState = rules.read(panelState, "");
assert.deepEqual(plain(panelState.unreadKeys), []);
assert.deepEqual(plain(panelState.toastKeys), []);
panelState = rules.publish(panelState,
    item("native:panel-during", "toast", 20), 20, true, true);
assert.deepEqual(plain(panelState.history.map(entry => entry.key)),
    ["native:panel-during", "native:panel-before"]);
assert.deepEqual(plain(panelState.unreadKeys), []);
assert.deepEqual(plain(panelState.toastKeys), []);
const staleUnmount = rules.unmountPanel(panelState, "notification-panel:DP-2");
assert.strictEqual(staleUnmount, panelState,
    "a stale screen teardown must not close the mounted panel state");
panelState = rules.unmountPanel(panelState, "notification-panel:DP-1");
assert.equal(panelState.panelOpen, false);
panelState = rules.publish(panelState,
    item("native:panel-after", "toast", 30), 30, true, true);
assert.deepEqual(plain(panelState.unreadKeys), ["native:panel-after"]);
assert.deepEqual(plain(panelState.toastKeys), ["native:panel-after"]);
console.log("PASS mounted panel clears toasts, reads arrivals, and restores routing on close");

state = rules.publish(state, item("native:3", "center", 300), 300, true, true);
state = rules.publish(state, item("internal:timer_finished:tea", "center", 400),
    400, true, true);
assert.equal(state.currentCritical.key, "native:3");
assert.deepEqual(plain(state.criticalQueue.map(entry => entry.key)),
    ["native:3", "internal:timer_finished:tea"]);
assert.equal("deadlineAt" in state, false);
assert.equal("remainingMs" in state, false);
assert.equal("paused" in state, false);
assert.deepEqual(plain(state.toastKeys), ["native:1"]);

const replacement = item("internal:timer_finished:tea", "center", 450,
    { summary: "Tea replacement" });
state = rules.publish(state, replacement, 450, true, true);
assert.deepEqual(plain(state.criticalQueue.map(entry => entry.key)),
    ["native:3", "internal:timer_finished:tea"]);
assert.equal(state.criticalQueue[1], replacement);
console.log("PASS critical routing is FIFO, deduplicated, and never creates a duplicate toast");

const completed = rules.complete(state, "native:3", 8000, true);
assert.equal(completed.currentCritical.key, "internal:timer_finished:tea");
assert.deepEqual(plain(completed.criticalQueue.map(entry => entry.key)),
    ["internal:timer_finished:tea"]);
assert.equal(centerRules.closePolicy(true, !!completed.currentCritical), "keep");
const actionExhausted = rules.complete(
    completed, "internal:timer_finished:tea", 12000, true);
assert.equal(actionExhausted.currentCritical, null);
assert.equal(centerRules.closePolicy(true, !!actionExhausted.currentCritical), "compact");
assert.equal(typeof rules.pause, "undefined");
assert.equal(typeof rules.resume, "undefined");
assert.equal(typeof rules.deadlineMatches, "undefined");
console.log("PASS coordinator completion advances FIFO without owning a presentation clock");

let gated = rules.setPresentationEligible(rules.initialState(), false, 0);
gated = rules.publish(gated, item("native:critical", "center", 10), 10, false, true);
assert.equal(gated.currentCritical, null);
assert.deepEqual(plain(gated.criticalQueue.map(entry => entry.key)), ["native:critical"]);
gated = rules.setPresentationEligible(gated, true, 100);
assert.equal(gated.currentCritical.key, "native:critical");
const stillVisible = rules.setPresentationEligible(gated, false, 200);
assert.equal(stillVisible.currentCritical, gated.currentCritical);
console.log("PASS ineligible Center state queues without preemption and preserves a visible item");

let capped = rules.initialState();
for (let index = 0; index < 120; index++)
    capped = rules.publish(capped, item(`native:${index + 1}`, "history", index),
        index, true, true);
assert.equal(capped.history.length, 100);
assert.equal(capped.unreadKeys.length, 100);
assert.equal(capped.unreadKeys.every(key =>
    capped.history.some(entry => entry.key === key)), true);
for (let index = 0; index < 5; index++)
    capped = rules.publish(capped, item(`native:toast-${index}`, "toast", 200 + index),
        200 + index, true, true);
assert.deepEqual(plain(capped.toastKeys),
    ["native:toast-4", "native:toast-3", "native:toast-2"]);
let criticalCap = rules.setPresentationEligible(rules.initialState(), false, 0);
for (let index = 0; index < 20; index++)
    criticalCap = rules.publish(criticalCap,
        item(`internal:job_failed:${index}`, "center", index), index, false, true);
assert.equal(criticalCap.criticalQueue.length, 16);
assert.deepEqual(plain(criticalCap.criticalQueue.slice(0, 2).map(entry => entry.key)),
    ["internal:job_failed:0", "internal:job_failed:1"]);
assert.equal(criticalCap.criticalQueue.at(-1).key, "internal:job_failed:15");
console.log("PASS history, toast, unread, and critical state obey their caps");

let visibleDuringBurst = rules.publish(rules.initialState(),
    item("native:visible", "center", 0), 0, true, true);
for (let index = 0; index < 105; index++)
    visibleDuringBurst = rules.publish(visibleDuringBurst,
        item(`native:burst-${index}`, "history", index + 1), index + 1, true, true);
assert.equal(visibleDuringBurst.history.length, 100);
assert.equal(visibleDuringBurst.history.some(entry => entry.key === "native:visible"), true);
assert.equal(visibleDuringBurst.unreadKeys.includes("native:visible"), true);
assert.equal(visibleDuringBurst.currentCritical.key, "native:visible");
console.log("PASS capped history retains the currently visible critical descriptor");

let queuedDuringBurst = rules.setPresentationEligible(rules.initialState(), false, 0);
for (let index = 0; index < 16; index++)
    queuedDuringBurst = rules.publish(queuedDuringBurst,
        item(`internal:job_failed:queued-${index}`, "center", index),
        index, false, true);
for (let index = 0; index < 100; index++)
    queuedDuringBurst = rules.publish(queuedDuringBurst,
        item(`native:passive-${index}`, "history", 100 + index),
        100 + index, false, true);
assert.equal(queuedDuringBurst.history.length, 100);
assert.equal(queuedDuringBurst.currentCritical, null);
assert.equal(queuedDuringBurst.criticalQueue.every(entry =>
    queuedDuringBurst.history.some(historyItem => historyItem.key === entry.key)), true);
assert.equal(queuedDuringBurst.criticalQueue.every(entry =>
    queuedDuringBurst.unreadKeys.includes(entry.key)), true);
assert.equal(queuedDuringBurst.unreadKeys.every(key =>
    queuedDuringBurst.history.some(entry => entry.key === key)), true);
console.log("PASS disabled presentation cannot leave queued critical keys outside capped history/unread");

const current = item("native:current", "center", 100);
const pending = item("native:pending", "center", 200);
const quiet = item("native:quiet", "toast", 300);
let reclassified = rules.publish(rules.initialState(), current, 100, true, true);
reclassified = rules.publish(reclassified, pending, 200, true, true);
reclassified = rules.publish(reclassified, quiet, 300, true, true);
const resolver = descriptor => {
    if (descriptor.key === "native:current")
        return Object.freeze(Object.assign({}, descriptor, { route: "history" }));
    if (descriptor.key === "native:pending")
        return Object.freeze(Object.assign({}, descriptor, { severity: "normal", route: "toast" }));
    return Object.freeze(Object.assign({}, descriptor, { route: "block" }));
};
reclassified = rules.reclassify(reclassified, {}, 900, resolver, true);
assert.equal(reclassified.currentCritical, current);
assert.deepEqual(plain(reclassified.criticalQueue.map(entry => entry.key)), ["native:current"]);
assert.deepEqual(plain(reclassified.history.map(entry => entry.key)),
    ["native:pending", "native:current"]);
assert.deepEqual(plain(reclassified.toastKeys), ["native:pending"]);
assert.deepEqual(plain(reclassified.unreadKeys), ["native:pending", "native:current"]);
console.log("PASS settings reclassification keeps visible critical content stable and reroutes pending items");

let promoted = rules.publish(rules.initialState(),
    item("native:normal-old", "toast", 100), 100, true, true);
promoted = rules.publish(promoted,
    item("native:normal-new", "toast", 200), 200, true, true);
promoted = rules.reclassify(promoted, {}, 500, descriptor => Object.freeze(
    Object.assign({}, descriptor, { severity: "critical", route: "center" })), true);
assert.equal(promoted.currentCritical.key, "native:normal-old");
assert.deepEqual(plain(promoted.criticalQueue.map(entry => entry.key)),
    ["native:normal-old", "native:normal-new"]);
assert.deepEqual(plain(promoted.toastKeys), []);
console.log("PASS normal toast reclassification promotes critical items in FIFO order");

let replacementOrder = rules.setPresentationEligible(rules.initialState(), false, 0);
replacementOrder = rules.publish(replacementOrder,
    item("native:queued-a", "center", 100), 100, false, true);
replacementOrder = rules.publish(replacementOrder,
    item("native:queued-b", "center", 200), 200, false, true);
replacementOrder = rules.publish(replacementOrder,
    item("native:promoted", "toast", 300), 300, false, true);
const refreshedQueuedA = item("native:queued-a", "center", 500,
    { summary: "Queued replacement" });
replacementOrder = rules.publish(replacementOrder,
    refreshedQueuedA, 500, false, true);
replacementOrder = rules.reclassify(replacementOrder, {}, 600,
    descriptor => descriptor.key === "native:promoted"
        ? Object.freeze(Object.assign({}, descriptor,
            { severity: "critical", route: "center" }))
        : descriptor, true);
assert.deepEqual(plain(replacementOrder.criticalQueue.map(entry => entry.key)),
    ["native:queued-a", "native:queued-b", "native:promoted"]);
assert.equal(replacementOrder.criticalQueue[0], refreshedQueuedA);
console.log("PASS reclassification preserves queued replacements before newly promoted toasts");

const committedPreferences = Object.freeze({ modules: Object.freeze({
    notifications: Object.freeze({
        policyMode: "automatic",
        allowCriticalOnIsland: true,
        toastsEnabled: true,
        applicationOverrides: Object.freeze({}),
    }),
}) });
const previewPreferences = [
    Object.freeze({ modules: Object.freeze({ notifications: Object.freeze({
        policyMode: "custom", allowCriticalOnIsland: true, toastsEnabled: true,
        applicationOverrides: Object.freeze({ "preview.desktop": "block" }),
    }) }) }),
    Object.freeze({ modules: Object.freeze({ notifications: Object.freeze({
        policyMode: "custom", allowCriticalOnIsland: true, toastsEnabled: true,
        applicationOverrides: Object.freeze({ "preview.desktop": "quiet" }),
    }) }) }),
    Object.freeze({ modules: Object.freeze({ notifications: Object.freeze({
        policyMode: "automatic", allowCriticalOnIsland: true, toastsEnabled: false,
        applicationOverrides: Object.freeze({}),
    }) }) }),
];
assert.equal(typeof rules.appliedPreferences, "function",
    "coordinator rules must select committed policy while Settings preview is active");
let previewBaseline = rules.publish(rules.initialState(), item(
    "native:visible-preview", "center", 100,
    { appId: "preview.desktop" }), 100, true, true);
previewBaseline = rules.publish(previewBaseline, item(
    "native:pending-preview", "toast", 200,
    { appId: "preview.desktop" }), 200, true, true);
for (const preview of previewPreferences) {
    const appliedDuringPreview = rules.appliedPreferences(
        preview, committedPreferences, true);
    assert.strictEqual(appliedDuringPreview, committedPreferences);
    const previewed = rules.reclassify(previewBaseline, appliedDuringPreview, 300,
        notificationRules.resolvePolicy,
        appliedDuringPreview.modules.notifications.toastsEnabled);
    const appliedAfterCancel = rules.appliedPreferences(
        committedPreferences, committedPreferences, false);
    const canceled = rules.reclassify(previewed, appliedAfterCancel, 400,
        notificationRules.resolvePolicy,
        appliedAfterCancel.modules.notifications.toastsEnabled);
    assert.strictEqual(previewed.currentCritical, previewBaseline.currentCritical,
        "preview must not replace the visible FIFO item");
    assert.strictEqual(canceled.currentCritical, previewBaseline.currentCritical,
        "Cancel must preserve the visible FIFO item");
    assert.deepEqual(plain(canceled.history.map(entry => entry.key)),
        ["native:pending-preview", "native:visible-preview"]);
    assert.deepEqual(plain(canceled.toastKeys), ["native:pending-preview"]);
    assert.deepEqual(plain(canceled.criticalQueue.map(entry => entry.key)),
        ["native:visible-preview"]);
}
console.log("PASS block, quiet, and toast-disable previews cancel without destructive reclassification");

const read = rules.read(reclassified, "native:pending");
assert.deepEqual(plain(read.unreadKeys), ["native:current"]);
const dismissed = rules.dismiss(read, "native:current", 1000);
assert.equal(dismissed.currentCritical, null);
assert.deepEqual(plain(dismissed.history.map(entry => entry.key)), ["native:pending"]);
assert.deepEqual(plain(dismissed.criticalQueue), []);
console.log("PASS read and dismiss intents update only matching stable keys");

let autoRead = rules.publish(rules.initialState(),
    item("native:auto-read", "center", 0), 0, true, true);
autoRead = rules.complete(autoRead, "native:auto-read", 4000, false);
assert.deepEqual(plain(autoRead.unreadKeys), []);
assert.equal(autoRead.history[0].key, "native:auto-read");
console.log("PASS completion honors disabled keep-critical-unread without removing history");

let retired = rules.publish(rules.initialState(),
    item("native:retired", "center", 0, {
        actions: Object.freeze([Object.freeze({ id: "open", label: "Open" })]),
    }), 0, true, true);
retired = rules.publish(retired,
    item("internal:timer_finished:next", "center", 1), 1, true, true);
retired = rules.retire(retired, "native:retired", "expired", 100);
assert.deepEqual(plain(retired.history.map(entry => entry.key)),
    ["internal:timer_finished:next", "native:retired"]);
assert.deepEqual(plain(retired.unreadKeys),
    ["internal:timer_finished:next", "native:retired"]);
assert.deepEqual(plain(retired.history.find(entry =>
    entry.key === "native:retired").actions), []);
assert.equal(retired.currentCritical.key, "internal:timer_finished:next");
assert.deepEqual(plain(retired.criticalQueue.map(entry => entry.key)),
    ["internal:timer_finished:next"]);
assert.deepEqual(plain(retired.toastKeys), []);
console.log("PASS expiry retires native presentation/actions without deleting session history/unread");

let explicitlyDismissed = rules.publish(rules.initialState(),
    item("native:explicit", "toast", 0, {
        actions: Object.freeze([Object.freeze({ id: "open", label: "Open" })]),
    }), 0, true, true);
explicitlyDismissed = rules.retire(
    explicitlyDismissed, "native:explicit", "dismissed", 100);
assert.deepEqual(plain(explicitlyDismissed.history), []);
assert.deepEqual(plain(explicitlyDismissed.unreadKeys), []);
assert.deepEqual(plain(explicitlyDismissed.toastKeys), []);
console.log("PASS explicit native dismissal removes coordinator history and unread state");
