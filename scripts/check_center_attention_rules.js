#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Center",
    "CenterAttentionRules.js");

if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing Titonium/Services/Center/CenterAttentionRules.js");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

let state = rules.initialState();
assert.deepEqual(plain(state), { current: null, pending: [], generation: 0 });

state = rules.publish(state, {
    id: "media:track",
    source: "media",
    kind: "track_changed",
    title: " Tycho · Awake ",
    icon: "music_note",
    priority: 99,
    ttl: 999999,
    createdAt: 1000,
}, 1000);
assert.equal(state.current.title, "Tycho · Awake");
assert.equal(state.current.priority, 20);
assert.equal(state.current.expiresAt, 9000);
assert.equal(state.generation, 1);
assert.equal(Object.isFrozen(state.current), true);
assert.equal("command" in state.current, false);
console.log("PASS Center policy owns normalized priority and TTL");

const firstGeneration = state.generation;
state = rules.publish(state, {
    id: "job:build",
    source: "job",
    kind: "job_failed",
    title: "Build failed",
    icon: "error",
    createdAt: 2000,
}, 2000);
assert.equal(state.current.id, "job:build");
assert.equal(state.current.priority, 70);
assert.equal(state.generation, 2);

const expiryRequest = rules.expiryRequest(state, 2000);
assert.deepEqual(plain(expiryRequest), {
    id: "job:build",
    generation: 2,
    delay: 15000,
});
assert.equal(rules.expire(state, expiryRequest.id, expiryRequest.generation,
    17000).current, null);
console.log("PASS expiry request carries arbiter generation instead of descriptor data");

const ignoredOldExpiry = rules.expire(state, "media:track", firstGeneration, 7000);
assert.strictEqual(ignoredOldExpiry, state);
assert.equal(ignoredOldExpiry.current.id, "job:build");
console.log("PASS higher priority preemption and generation-safe expiry");

const beforeDropped = state;
state = rules.publish(state, {
    id: "media:paused",
    source: "media",
    kind: "paused",
    title: "Paused",
    icon: "pause",
    createdAt: 3000,
}, 3000);
assert.strictEqual(state, beforeDropped);
assert.deepEqual(plain(state.pending), []);
console.log("PASS lower ephemeral event is dropped instead of queued");

let equalState = rules.publish(rules.initialState(), {
    id: "media:first", source: "media", kind: "paused", title: "First",
    icon: "pause", createdAt: 100,
}, 100);
equalState = rules.publish(equalState, {
    id: "media:second", source: "media", kind: "resumed", title: "Second",
    icon: "play", createdAt: 200,
}, 200);
assert.equal(equalState.current.id, "media:second");
console.log("PASS equal priority uses newest-wins ordering");

let dedupState = rules.publish(rules.initialState(), {
    id: "media:current", source: "media", kind: "track_changed",
    deduplicationKey: "media:current", title: "Old track", icon: "music_note",
    createdAt: 1000,
}, 1000);
dedupState = rules.publish(dedupState, {
    id: "media:current", source: "media", kind: "track_changed",
    deduplicationKey: "media:current", title: "New track", icon: "music_note",
    createdAt: 2000,
}, 2000);
assert.equal(dedupState.current.title, "New track");
assert.equal(dedupState.current.expiresAt, 10000);
assert.equal(dedupState.generation, 2);
console.log("PASS matching deduplication key replaces and renews presentation");

const expiredState = rules.expire(dedupState, "media:current",
    dedupState.generation, 10000);
assert.equal(expiredState.current, null);
assert.equal(expiredState.generation, 3);
console.log("PASS matching current event expires into fallback state");

let pendingState = rules.publish(rules.initialState(), {
    id: "system:critical", source: "center", kind: "critical",
    title: "Critical", icon: "warning", createdAt: 1000,
}, 1000);
pendingState = rules.publish(pendingState, {
    id: "job:deploy", source: "job", kind: "job_requires_action",
    title: "Approve deploy", icon: "task", createdAt: 2000,
}, 2000);
assert.equal(pendingState.current.id, "system:critical");
assert.deepEqual(plain(pendingState.pending).map(item => item.id), ["job:deploy"]);
pendingState = rules.acknowledge(pendingState, "system:critical", 3000);
assert.equal(pendingState.current.id, "job:deploy");
assert.equal(pendingState.generation, 2);
assert.deepEqual(plain(pendingState.pending), []);
console.log("PASS lower actionable event waits and resumes after acknowledgement");

let clearState = rules.publish(rules.initialState(), {
    id: "job:one", source: "job", kind: "job_requires_action",
    title: "One", icon: "task", createdAt: 1000,
}, 1000);
clearState = rules.publish(clearState, {
    id: "job:two", source: "job", kind: "job_requires_action",
    title: "Two", icon: "task", createdAt: 2000,
}, 2000);
clearState = rules.clear(clearState, "job:two", 3000);
assert.equal(clearState.current.id, "job:one");
clearState = rules.clearSource(clearState, "job", 4000);
assert.equal(clearState.current, null);
assert.deepEqual(plain(clearState.pending), []);
console.log("PASS exact and source clears remove only matching actionable state");

let importanceState = rules.publish(rules.initialState(), {
    id: "job:important-fail", source: "job", kind: "job_failed",
    importance: "important", title: "Important failure", icon: "error",
    createdAt: 1000,
}, 1000);
assert.equal(importanceState.current.priority, 80);
importanceState = rules.publish(importanceState, {
    id: "job:important-action", source: "job", kind: "job_requires_action",
    importance: "important", title: "Important action", icon: "task",
    createdAt: 2000,
}, 2000);
assert.equal(importanceState.current.priority, 90);
console.log("PASS important jobs receive bounded policy boost");

const invalidBase = rules.initialState();
for (const invalid of [
    null,
    {},
    { id: "x", source: "volume", kind: "changed", title: "Volume" },
    { id: "x", source: "media", kind: "unknown", title: "Unknown" },
    { id: "x", source: "media", kind: "paused", title: "   " },
]) {
    assert.strictEqual(rules.publish(invalidBase, invalid, 1000), invalidBase);
}
console.log("PASS malformed and non-allowlisted events fail closed");

for (const event of [
    { id: "clipboard:current", source: "clipboard", kind: "copied",
        title: "Đã sao chép · hello", icon: "content_copy", createdAt: 1000 },
    { id: "notification:new", source: "notification", kind: "new",
        title: "Bạn có một notification", icon: "notifications", createdAt: 2000 },
]) {
    const projected = rules.publish(rules.initialState(), event, event.createdAt);
    assert.equal(projected.current.priority, 25);
    assert.equal(projected.current.expiresAt,
        event.createdAt + (event.source === "notification" ? 12000 : 7000));
}
console.log("PASS Clipboard and new Notification own bounded source-specific takeover policy");

let indicators = Object.freeze([]);
indicators = rules.setIndicator(indicators, {
    id: "media", icon: "music_note", accessibleName: "Media playing", active: true,
});
assert.deepEqual(plain(indicators), [{
    id: "media", icon: "music_note", accessibleName: "Media playing",
}]);
assert.equal(Object.isFrozen(indicators), true);
assert.equal(Object.isFrozen(indicators[0]), true);
indicators = rules.setIndicator(indicators, {
    id: "media", icon: "music_note", accessibleName: "Updated media", active: true,
});
assert.equal(indicators.length, 1);
assert.equal(indicators[0].accessibleName, "Updated media");
indicators = rules.setIndicator(indicators, { id: "media", active: false });
assert.deepEqual(plain(indicators), []);
console.log("PASS passive indicators upsert and clear independently");
