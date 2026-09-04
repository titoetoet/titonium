#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const rulesPath = path.join(__dirname, "..", "Titonium", "Core", "Surfaces",
    "Center", "CenterSurfaceState.js");
if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing CenterSurfaceState.js");
    process.exit(1);
}
const rules = vm.createContext({});
vm.runInContext(fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, ""),
    rules, { filename: rulesPath });
function plain(value) { return JSON.parse(JSON.stringify(value)); }

const snapshot = Object.freeze({
    primary: Object.freeze({ id: "focus:daily", attention: "ambient" }),
    secondary: Object.freeze({ id: "notification:42", attention: "transient" }),
    contexts: Object.freeze([
        Object.freeze({ id: "focus:daily", attention: "ambient" }),
        Object.freeze({ id: "notification:42", attention: "transient" }),
        Object.freeze({ id: "agent:req", attention: "blocking" }),
    ]),
});

let state = rules.initialState();
assert.equal(state.mode, "closed");
state = rules.transition(state, snapshot,
    { type: "surface-granted", screenName: "DP-1" }, 1000);
assert.equal(state.mode, "compact");
assert.equal(state.ownerScreenName, "DP-1");
const firstGeneration = state.generation;
state = rules.transition(state, snapshot, {
    type: "present", contextId: "notification:42", requestedMode: "banner",
    timeoutMs: 4000, focusPolicy: "none",
}, 1100);
assert.deepEqual([state.mode, state.deadline, state.selectedContextId],
    ["banner", 5100, "notification:42"]);
assert.ok(state.generation > firstGeneration);
assert.ok(Object.isFrozen(state));
console.log("PASS Center surface opens compact and timed banner through explicit grants");

const bannerGeneration = state.generation;
assert.strictEqual(rules.transition(state, snapshot,
    { type: "transition-finished", generation: bannerGeneration - 1 }, 1200), state);
state = rules.pauseDeadline(state, 2100);
assert.deepEqual([state.deadline, state.remainingMs], [0, 3000]);
state = rules.resumeDeadline(state, 3000);
assert.deepEqual([state.deadline, state.remainingMs], [6000, 0]);
console.log("PASS deadline pause/resume preserves remaining duration and stale generations fail closed");

state = rules.transition(state, snapshot, { type: "request-mode", mode: "expanded" }, 3200);
assert.equal(state.mode, "expanded");
assert.equal(state.focusPolicy, "exclusive");
const unchanged = rules.transition(state, snapshot, {
    type: "present", contextId: "notification:42", requestedMode: "banner",
    timeoutMs: 4000, focusPolicy: "none",
}, 3300);
assert.strictEqual(unchanged, state);
console.log("PASS transient presentation never interrupts expanded interaction");

let selected = rules.transition(state, snapshot,
    { type: "activate-context", contextId: "notification:42" }, 3400);
const withoutNotification = Object.freeze({
    primary: snapshot.primary, secondary: null,
    contexts: Object.freeze([snapshot.primary])
});
selected = rules.transition(selected, withoutNotification, { type: "snapshot-changed" }, 3500);
assert.equal(selected.selectedContextId, "focus:daily");
console.log("PASS vanished selection falls back to domain primary without re-arbitration");

assert.deepEqual(plain(rules.dragSettlePlan(0.2, 48, 0)), {
    targetState: "expanded", targetProgress: 1, duration: 162
});
assert.equal(rules.dragSettlePlan(0.2, 0, 500).targetState, "expanded");
assert.equal(rules.dragSettlePlan(0.2, 20, 100).targetState, "banner");
console.log("PASS drag settlement is deterministic and controller-owned");

const closed = rules.transition(selected, withoutNotification,
    { type: "surface-revoked", reason: "screen-removed" }, 4000);
assert.equal(closed.mode, "closed");
assert.equal(closed.ownerScreenName, "");
assert.ok(closed.generation > selected.generation);
console.log("PASS surface revocation closes ownership generation-safely");
