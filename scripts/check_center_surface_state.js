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
const rulesSource = fs.readFileSync(rulesPath, "utf8");
vm.runInContext(rulesSource.replace(/^\.pragma library\s*\n/, ""),
    rules, { filename: rulesPath });
function plain(value) { return JSON.parse(JSON.stringify(value)); }

const snapshot = Object.freeze({
    primary: Object.freeze({ id: "focus:daily", attention: "ambient" }),
    secondary: Object.freeze({ id: "notification:42", attention: "transient" }),
    contexts: Object.freeze([
        Object.freeze({ id: "focus:daily", attention: "ambient" }),
        Object.freeze({ id: "notification:42", attention: "transient" }),
        Object.freeze({ id: "notification:43", attention: "transient" }),
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
    timeoutMs: 4000, focusPolicy: "none", presentationOwner: "notification",
    acquisitionPolicy: "non-preemptive",
}, 1100);
assert.deepEqual([state.mode, state.deadline, state.selectedContextId],
    ["banner", 5100, "notification:42"]);
assert.equal(state.presentationOwner, "notification");
assert.equal(state.deadlineToken, 5100);
assert.ok(state.generation > firstGeneration);
assert.ok(Object.isFrozen(state));
console.log("PASS Center surface opens compact and timed banner through explicit grants");

const compactWithLiveSecondary = Object.freeze({
    primary: Object.freeze({ id: "focus:daily", attention: "ambient" }),
    secondary: Object.freeze({ id: "media:current", attention: "ambient" }),
    contexts: Object.freeze([
        Object.freeze({ id: "focus:daily", attention: "ambient" }),
        Object.freeze({ id: "media:current", attention: "ambient" }),
    ]),
});
const compactState = rules.transition(rules.initialState(), compactWithLiveSecondary,
    { type: "surface-granted", screenName: "DP-1" }, 1000);
assert.equal(compactState.mode, "compact");
assert.equal(compactWithLiveSecondary.secondary.id, "media:current");
assert.equal(rules.automaticPresentationEligible(
    compactState, compactWithLiveSecondary), true);
assert.equal(rules.automaticPresentationEligible(state, snapshot), true);
assert.equal(rules.automaticPresentationEligible(Object.assign({}, state, {
    mode: "expanded", presentationOwner: "user",
}), snapshot), false);
assert.equal(rules.automaticPresentationEligible(Object.assign({}, state, {
    mode: "banner", presentationOwner: "user", acquisitionPolicy: "preemptive",
}), snapshot), false);
assert.doesNotMatch(rulesSource, /["']satellite["']/,
    "satellite presentation is represented by compact state plus a live secondary context");
console.log("PASS compact live-secondary and the owned banner permit automatic entry");

const replacement = rules.transition(state, snapshot, {
    type: "present", contextId: "notification:43", requestedMode: "banner",
    timeoutMs: 4000, focusPolicy: "none", presentationOwner: "notification",
    acquisitionPolicy: "non-preemptive",
}, 1200);
assert.deepEqual([replacement.mode, replacement.selectedContextId,
    replacement.presentationOwner, replacement.deadline],
["banner", "notification:43", "notification", 5200]);
assert.equal(replacement.deadlineToken, 5200);
const userBanner = rules.transition(rules.transition(rules.initialState(), snapshot,
    { type: "surface-granted", screenName: "DP-1" }, 0), snapshot, {
    type: "present", contextId: "focus:daily", requestedMode: "banner",
    timeoutMs: 0, focusPolicy: "none", presentationOwner: "user",
}, 100);
assert.strictEqual(rules.transition(userBanner, snapshot, {
    type: "present", contextId: "notification:42", requestedMode: "banner",
    timeoutMs: 4000, focusPolicy: "none", presentationOwner: "notification",
    acquisitionPolicy: "non-preemptive",
}, 200), userBanner);
console.log("PASS FIFO content can replace its banner without preempting user-owned context");

assert.strictEqual(rules.applyPresentationResult(replacement, snapshot, {
    accepted: true, closePolicy: "keep",
}, 1300), replacement);
const exhausted = rules.applyPresentationResult(replacement, snapshot, {
    accepted: true, closePolicy: "compact",
}, 1300);
assert.equal(exhausted.mode, "compact");
assert.equal(exhausted.presentationOwner, "");
assert.equal(exhausted.deadline, 0);
console.log("PASS FIFO completion keeps the banner until queue exhaustion then collapses");

const bannerGeneration = state.generation;
assert.strictEqual(rules.transition(state, snapshot,
    { type: "transition-finished", generation: bannerGeneration - 1 }, 1200), state);
const firstDeadlineIdentity = Object.freeze({
    generation: state.generation,
    contextId: state.selectedContextId,
    deadline: state.deadlineToken,
});
assert.equal(typeof rules.timedPresentationMatches, "function",
    "timed presentation identity matching must be available");
assert.equal(rules.timedPresentationMatches(state, firstDeadlineIdentity), true);
assert.equal(rules.timedPresentationMatches(replacement, firstDeadlineIdentity), false);
assert.equal(rules.deadlineMatches(state, firstDeadlineIdentity, 5100), true);
assert.equal(rules.deadlineMatches(replacement, firstDeadlineIdentity, 6000), false);
assert.strictEqual(rules.pauseDeadline(replacement, firstDeadlineIdentity, 2100), replacement);
assert.strictEqual(rules.pauseDeadline(state, firstDeadlineIdentity, 5100), state,
    "an elapsed exact deadline must stay armed for controller completion");
assert.strictEqual(rules.transition(replacement, snapshot,
    Object.assign({ type: "timeout" }, firstDeadlineIdentity), 6000), replacement);
state = rules.pauseDeadline(state, firstDeadlineIdentity, 2100);
assert.deepEqual([state.deadline, state.remainingMs], [0, 3000]);
state = rules.resumeDeadline(state, firstDeadlineIdentity, 3000);
assert.deepEqual([state.deadline, state.remainingMs], [6000, 0]);
assert.equal(state.deadlineToken, 6000);
assert.strictEqual(rules.resumeDeadline(state, firstDeadlineIdentity, 3100), state);
console.log("PASS deadline controls preserve time and reject stale generation/context/deadline identities");

state = rules.transition(state, snapshot, { type: "request-mode", mode: "expanded" }, 3200);
assert.equal(state.mode, "expanded");
assert.equal(state.focusPolicy, "exclusive");
const unchanged = rules.transition(state, snapshot, {
    type: "present", contextId: "notification:42", requestedMode: "banner",
    timeoutMs: 4000, focusPolicy: "none", presentationOwner: "notification",
    acquisitionPolicy: "non-preemptive",
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
const finished = rules.transition(closed, withoutNotification, {
    type: "finish-close", screenName: closed.exitingScreenName,
    generation: closed.generation,
}, 4100);
assert.equal(finished.exitingScreenName, "");
console.log("PASS surface revocation closes ownership generation-safely");
