#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const rulesPath = path.join(__dirname, "..", "Titonium", "Bar", "center",
    "presentations", "Classic", "ClassicPopupTransitionRules.js");
const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });
const plain = value => JSON.parse(JSON.stringify(value));
const ownershipPath = path.join(__dirname, "..", "Titonium", "Core", "Surfaces",
    "Center", "CenterSurfacePresentationRules.js");
const ownershipSource = fs.readFileSync(ownershipPath, "utf8")
    .replace(/^\.pragma library\s*\n/, "");
const ownership = vm.createContext({});
vm.runInContext(ownershipSource, ownership, { filename: ownershipPath });

assert.equal(ownership.transitionOwner({ ownerScreenName: "DP-1",
    exitingScreenName: "", mode: "banner" }, "DP-1"), true);
assert.equal(ownership.transitionOwner({ ownerScreenName: "DP-1",
    exitingScreenName: "", mode: "banner" }, "DP-2"), false);
assert.equal(ownership.transitionOwner({ ownerScreenName: "",
    exitingScreenName: "DP-1", mode: "closed" }, "DP-1"), true);
assert.equal(ownership.transitionOwner({ ownerScreenName: "",
    exitingScreenName: "DP-1", mode: "closed" }, "DP-2"), false);
console.log("PASS Classic transition ownership follows only the owning or dismissing screen");

const compactExitState = { ownerScreenName: "DP-1", exitingScreenName: "",
    mode: "compact", generation: 21 };
assert.equal(ownership.compactExitPending(
    compactExitState, "DP-1", "DP-1", 20, 0), true);
assert.equal(ownership.compactExitPending(
    compactExitState, "DP-2", "", 0, 0), false);
assert.equal(ownership.compactExitPending(
    compactExitState, "DP-1", "DP-1", 20, 21), false);
assert.equal(ownership.compactExitPending(
    { ...compactExitState, ownerScreenName: "DP-2" },
    "DP-1", "DP-1", 20, 0), false);
console.log("PASS only the exact outgoing popup owner retains compact-exit generation");

let state = rules.initialState();
let result = rules.transition(state, {
    mode: "banner", generation: 4, transitionOwner: false, reducedMotion: false,
    visual: { opacity: 1, scale: 1, y: 0 }, contextId: "critical:1",
});
assert.deepEqual(plain(result.effects), []);
assert.equal(result.state.phase, "idle");
console.log("PASS inactive and hidden Classic renderers never drive transitions");

result = rules.transition(state, {
    mode: "banner", generation: 4, transitionOwner: true, reducedMotion: false,
    visual: { opacity: 1, scale: 1, y: 0 }, contextId: "critical:1",
});
state = result.state;
assert.deepEqual(plain(result.effects), [{
    type: "animate", phase: "opening", token: 1, generation: 4,
    from: { opacity: 0, scale: 0.94, y: -12 },
    to: { opacity: 1, scale: 1, y: 0 },
    duration: { opacity: 150, scale: 220, y: 220 },
}]);

const openingToken = state.token;
result = rules.transition(state, {
    mode: "banner", generation: 4, transitionOwner: true, reducedMotion: false,
    visual: { opacity: 0.2, scale: 0.955, y: -8 }, contextId: "critical:1",
    deadline: 9999,
});
assert.equal(result.state, state);
assert.equal(result.state.token, openingToken);
assert.deepEqual(plain(result.effects), []);
console.log("PASS same-generation deadline updates do not interrupt popup entrance");

result = rules.transition(state, {
    mode: "expanded", generation: 5, transitionOwner: true, reducedMotion: false,
    visual: { opacity: 0.43, scale: 0.972, y: -5 }, contextId: "approval:1",
});
state = result.state;
assert.equal(state.presentedMode, "expanded");
assert.equal(state.presentedContextId, "approval:1");
assert.deepEqual(plain(result.effects), [
    { type: "cancel-animation", token: 1 },
    { type: "complete", token: 2, generation: 5 },
]);
assert.deepEqual(plain(rules.complete(state, 1).effects), [],
    "superseded opening callbacks must be stale");
result = rules.complete(state, 2);
state = result.state;
assert.deepEqual(plain(result.effects), [{ type: "emit-completion", generation: 5 }]);
assert.deepEqual(plain(rules.complete(state, 2).effects), [],
    "one transition token must complete exactly once");
console.log("PASS popup-to-popup replacement completes its immutable generation exactly once");

result = rules.transition(state, {
    mode: "compact", generation: 6, transitionOwner: true, reducedMotion: false,
    visual: { opacity: 0.61, scale: 0.981, y: -3 }, contextId: "focus",
});
state = result.state;
assert.equal(state.presentedMode, "expanded");
assert.equal(state.presentedContextId, "approval:1");
assert.deepEqual(plain(result.effects), [{
    type: "animate", phase: "closing", token: 3, generation: 6,
    from: { opacity: 0.61, scale: 0.981, y: -3 },
    to: { opacity: 0, scale: 0.96, y: -8 },
    duration: { opacity: 120, scale: 130, y: 130 },
}]);
result = rules.transition(state, {
    mode: "banner", generation: 7, transitionOwner: true, reducedMotion: false,
    visual: { opacity: 0.39, scale: 0.973, y: -4 }, contextId: "critical:2",
});
state = result.state;
assert.deepEqual(plain(result.effects), [
    { type: "cancel-animation", token: 3 },
    { type: "animate", phase: "opening", token: 4, generation: 7,
        from: { opacity: 0.39, scale: 0.973, y: -4 },
        to: { opacity: 1, scale: 1, y: 0 },
        duration: { opacity: 150, scale: 220, y: 220 } },
]);
assert.equal(state.presentedContextId, "critical:2");
console.log("PASS rapid close/reopen reverses from current values and caches outgoing content");

result = rules.transition(state, {
    mode: "compact", generation: 8, transitionOwner: true, reducedMotion: false,
    visual: { opacity: 0.52, scale: 0.984, y: -2 }, contextId: "focus",
});
state = result.state;

result = rules.setReducedMotion(state, true);
state = result.state;
assert.deepEqual(plain(result.effects), [
    { type: "cancel-animation", token: 5 },
    { type: "normalize", opacity: 0, scale: 0.96, y: -8 },
    { type: "emit-completion", generation: 8 },
]);
assert.equal(state.phase, "idle");
assert.equal(state.presentedMode, "");
assert.equal(state.presentedContextId, "");
assert.deepEqual(plain(rules.complete(state, 5).effects), []);
console.log("PASS mid-flight Reduced Motion normalizes and completes once");

state = rules.initialState();
result = rules.transition(state, { mode: "banner", generation: 10,
    transitionOwner: true, reducedMotion: false, contextId: "critical:10" });
state = rules.complete(result.state, result.state.token).state;
result = rules.transition(state, { mode: "compact", generation: 11,
    transitionOwner: true, reducedMotion: false,
    visual: { opacity: 1, scale: 1, y: 0 } });
state = rules.complete(result.state, result.state.token).state;
assert.equal(state.presentedMode, "");
assert.equal(state.presentedContextId, "");
result = rules.transition(state, { mode: "banner", generation: 12,
    transitionOwner: true, reducedMotion: false, contextId: "critical:12" });
assert.deepEqual(plain(result.effects), [{
    type: "animate", phase: "opening", token: 3, generation: 12,
    from: { opacity: 0, scale: 0.94, y: -12 },
    to: { opacity: 1, scale: 1, y: 0 },
    duration: { opacity: 150, scale: 220, y: 220 },
}]);
console.log("PASS completed close clears cached presentation for a fresh visible entrance");

state = rules.initialState();
result = rules.transition(state, { mode: "banner", generation: 30,
    transitionOwner: true, reducedMotion: false, contextId: "critical:30" });
state = rules.complete(result.state, result.state.token).state;
result = rules.transition(state, { mode: "compact", generation: 31,
    transitionOwner: ownership.compactExitPending(
        { ownerScreenName: "DP-1", mode: "compact", generation: 31 },
        "DP-1", "DP-1", 30, 0),
    reducedMotion: true, visual: { opacity: 1, scale: 1, y: 0 } });
state = result.state;
assert.deepEqual(plain(result.effects), [
    { type: "normalize", opacity: 0, scale: 0.96, y: -8 },
    { type: "emit-completion", generation: 31 },
]);
assert.equal(state.phase, "idle");
assert.equal(state.completionPending, false);
assert.equal(state.presentedMode, "");
assert.equal(state.presentedContextId, "");
assert.deepEqual(plain(rules.complete(state, state.token).effects), []);
result = rules.transition(state, { mode: "banner", generation: 32,
    transitionOwner: true, reducedMotion: false, contextId: "critical:32" });
assert.equal(result.effects[0].type, "animate");
assert.equal(result.effects[0].phase, "opening");
assert.deepEqual(plain(result.effects[0].from),
    { opacity: 0, scale: 0.94, y: -12 });
console.log("PASS reduced compact close snaps once and later reopen enters normally");

assert.deepEqual(plain(rules.bannerContextReplacement(
    "critical:1", "critical:2", false)), {
    kind: "crossfade", exitMs: 80, enterMs: 120,
});
assert.deepEqual(plain(rules.bannerContextReplacement(
    "critical:1", "critical:2", true)), {
    kind: "replace", exitMs: 0, enterMs: 0,
});
assert.deepEqual(plain(rules.bannerContextReplacement(
    "critical:1", "critical:1", false)), {
    kind: "unchanged", exitMs: 0, enterMs: 0,
});
console.log("PASS FIFO banner context replacement crossfades only the visible banner layer");

assert.deepEqual(plain(rules.transformedBounds(
    { x: 720, y: 52, width: 480, height: 72 }, 0.94, -12)), {
    x: 734.4, y: 40, width: 451.2, height: 67.68,
});
assert.deepEqual(plain(rules.popupGeometry(
    { width: 480, height: 72 }, { width: 1920, height: 96 }, 52)), {
    x: 720, y: 52, width: 480, height: 44,
});
assert.deepEqual(plain(rules.bannerLayout(480, 72, 16)), {
    contentWidth: 448, contentHeight: 40, iconSize: 18,
    actionHeight: 28, titleLines: 1, subtitleLines: 1,
});
console.log("PASS painted bounds, short-screen clamp, and padded banner layout are deterministic");
