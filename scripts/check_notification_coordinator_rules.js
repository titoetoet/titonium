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

state = rules.publish(state, item("native:3", "center", 300), 300, true, true);
state = rules.publish(state, item("internal:timer_finished:tea", "center", 400),
    400, true, true);
assert.equal(state.currentCritical.key, "native:3");
assert.deepEqual(plain(state.criticalQueue.map(entry => entry.key)),
    ["native:3", "internal:timer_finished:tea"]);
assert.equal(state.deadlineAt, 4300);
assert.deepEqual(plain(state.toastKeys), ["native:1"]);

const replacement = item("internal:timer_finished:tea", "center", 450,
    { summary: "Tea replacement" });
state = rules.publish(state, replacement, 450, true, true);
assert.deepEqual(plain(state.criticalQueue.map(entry => entry.key)),
    ["native:3", "internal:timer_finished:tea"]);
assert.equal(state.criticalQueue[1], replacement);
assert.equal(state.deadlineAt, 4300);
console.log("PASS critical routing is FIFO, deduplicated, and never creates a duplicate toast");

const paused = rules.pause(state, 1300);
assert.equal(paused.paused, true);
assert.equal(paused.remainingMs, 3000);
assert.equal(paused.deadlineAt, 0);
const resumed = rules.resume(paused, 5000);
assert.equal(resumed.paused, false);
assert.equal(resumed.remainingMs, 3000);
assert.equal(resumed.deadlineAt, 8000);
const completed = rules.complete(resumed, "native:3", 8000, true);
assert.equal(completed.currentCritical.key, "internal:timer_finished:tea");
assert.equal(completed.deadlineAt, 12000);
assert.deepEqual(plain(completed.criticalQueue.map(entry => entry.key)),
    ["internal:timer_finished:tea"]);
console.log("PASS pause/resume preserves remaining readable time and completion advances FIFO");

let gated = rules.setPresentationEligible(rules.initialState(), false, 0);
gated = rules.publish(gated, item("native:critical", "center", 10), 10, false, true);
assert.equal(gated.currentCritical, null);
assert.deepEqual(plain(gated.criticalQueue.map(entry => entry.key)), ["native:critical"]);
gated = rules.setPresentationEligible(gated, true, 100);
assert.equal(gated.currentCritical.key, "native:critical");
assert.equal(gated.deadlineAt, 4100);
const stillVisible = rules.setPresentationEligible(gated, false, 200);
assert.equal(stillVisible.currentCritical, gated.currentCritical);
assert.equal(stillVisible.deadlineAt, gated.deadlineAt);
console.log("PASS ineligible Center state queues without preemption and preserves a visible item");

let capped = rules.initialState();
for (let index = 0; index < 120; index++)
    capped = rules.publish(capped, item(`native:${index + 1}`, "history", index),
        index, true, true);
assert.equal(capped.history.length, 100);
assert.equal(capped.unreadKeys.length, 100);
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

const current = item("native:current", "center", 100);
const pending = item("native:pending", "center", 200);
const quiet = item("native:quiet", "toast", 300);
let reclassified = rules.publish(rules.initialState(), current, 100, true, true);
reclassified = rules.publish(reclassified, pending, 200, true, true);
reclassified = rules.publish(reclassified, quiet, 300, true, true);
const oldDeadline = reclassified.deadlineAt;
const resolver = descriptor => {
    if (descriptor.key === "native:current")
        return Object.freeze(Object.assign({}, descriptor, { route: "history" }));
    if (descriptor.key === "native:pending")
        return Object.freeze(Object.assign({}, descriptor, { severity: "normal", route: "toast" }));
    return Object.freeze(Object.assign({}, descriptor, { route: "block" }));
};
reclassified = rules.reclassify(reclassified, {}, 900, resolver, true);
assert.equal(reclassified.currentCritical, current);
assert.equal(reclassified.deadlineAt, oldDeadline);
assert.deepEqual(plain(reclassified.criticalQueue.map(entry => entry.key)), ["native:current"]);
assert.deepEqual(plain(reclassified.history.map(entry => entry.key)),
    ["native:pending", "native:current"]);
assert.deepEqual(plain(reclassified.toastKeys), ["native:pending"]);
assert.deepEqual(plain(reclassified.unreadKeys), ["native:pending", "native:current"]);
console.log("PASS settings reclassification keeps visible critical content stable and reroutes pending items");

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
