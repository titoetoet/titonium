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
const rendererPath = path.join(__dirname, "..", "Titonium", "Bar", "center",
    "presentations", "Classic", "ClassicRenderer.qml");
const rendererSource = fs.readFileSync(rendererPath, "utf8");
const ownershipPath = path.join(__dirname, "..", "Titonium", "Core", "Surfaces",
    "Center", "CenterSurfacePresentationRules.js");
const ownershipSource = fs.readFileSync(ownershipPath, "utf8")
    .replace(/^\.pragma library\s*\n/, "");
const ownership = vm.createContext({});
vm.runInContext(ownershipSource, ownership, { filename: ownershipPath });

const activatedOwner = ownership.classicOpenOwner("classic", {
    ownerScreenName: "DP-1", mode: "expanded", generation: 70,
}, "DP-1");
assert.deepEqual(plain(activatedOwner), { screenName: "DP-1", generation: 70 });
assert.equal(ownership.compactExitPending({
    ownerScreenName: "DP-1", mode: "compact", generation: 71,
}, "DP-1", activatedOwner.screenName, activatedOwner.generation, 0), true,
"a popup already open when Classic activates must retain its exact close generation");
let activatedState = rules.initialState();
let activatedOpen = rules.transition(activatedState, {
    mode: "expanded", generation: activatedOwner.generation,
    transitionOwner: true, reducedMotion: false, contextId: "focus",
});
activatedState = rules.complete(activatedOpen.state, activatedOpen.state.token).state;
const activatedPending = ownership.compactExitPending({
    ownerScreenName: "DP-1", mode: "compact", generation: 71,
}, "DP-1", activatedOwner.screenName, activatedOwner.generation, 0);
const activatedClose = rules.transition(activatedState, {
    mode: "compact", generation: 71, transitionOwner: activatedPending,
    reducedMotion: false, visual: { opacity: 1, scale: 1, y: 0 },
});
assert.equal(activatedClose.effects[0].phase, "closing");
const activatedCompletion = rules.complete(
    activatedClose.state, activatedClose.state.token);
assert.deepEqual(plain(activatedCompletion.effects), [
    { type: "normalize", opacity: 0, scale: 0.96, y: -8 },
    { type: "emit-completion", generation: 71 },
]);
assert.equal(ownership.compactExitPending({
    ownerScreenName: "DP-1", mode: "compact", generation: 71,
}, "DP-1", "", 0, 71), false);
assert.equal(ownership.classicOpenOwner("classic", {
    ownerScreenName: "DP-1", mode: "expanded", generation: 70,
}, "DP-2"), null);
assert.equal(ownership.classicOpenOwner("connected", {
    ownerScreenName: "DP-1", mode: "expanded", generation: 70,
}, "DP-1"), null);
assert.equal(ownership.classicOpenOwner("classic", {
    ownerScreenName: "DP-1", mode: "compact", generation: 71,
}, "DP-1"), null);

const overlaySource = fs.readFileSync(path.join(__dirname, "..", "Titonium", "Core",
    "Surfaces", "Center", "CenterOverlayWindow.qml"), "utf8");
assert.match(overlaySource,
    /function captureClassicOpenOwner\(\): void[\s\S]*?PresentationRules\.classicOpenOwner\(/);
assert.match(overlaySource, /onOwnsOverlayChanged:[\s\S]*?window\.captureClassicOpenOwner\(\)/);
assert.match(overlaySource, /onProfileChanged:\s*window\.captureClassicOpenOwner\(\)/);
assert.match(overlaySource,
    /Component\.onCompleted:[\s\S]*?window\.captureClassicOpenOwner\(\)/);
console.log("PASS Classic activation captures an already-open exact owner generation");

assert.doesNotMatch(rendererSource, /popupViewportReady|shouldReconcileViewport|viewportReady/,
    "the always-mapped Classic host must not defer transitions behind native viewport remapping");
console.log("PASS Classic popup reconciles directly inside its always-mapped host");

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

// A close before an entrance has painted still needs one generation-scoped
// completion so the controller can release the logical transition owner.
let deferredState = rules.initialState();
const deferredPending = ownership.compactExitPending({ ownerScreenName: "DP-1",
    exitingScreenName: "", mode: "compact", generation: 51 },
"DP-1", "DP-1", 50, 0);
let deferredClose = rules.transition(deferredState, { mode: "compact", generation: 51,
    transitionOwner: deferredPending, reducedMotion: false });
assert.deepEqual(plain(deferredClose.effects), [
    { type: "emit-completion", generation: 51 },
]);
deferredState = deferredClose.state;
assert.deepEqual(plain(rules.transition(deferredState, {
    mode: "compact", generation: 51, transitionOwner: deferredPending,
    reducedMotion: false,
}).effects), []);
assert.deepEqual(plain(rules.transition(rules.initialState(), {
    mode: "compact", generation: 51, transitionOwner: false,
    reducedMotion: false,
}).effects), []);
console.log("PASS pre-paint owned close releases once while DP-2 stays inactive");

let dp1State = rules.initialState();
let dp1Open = rules.transition(dp1State, { mode: "banner", generation: 40,
    transitionOwner: ownership.transitionOwner({ ownerScreenName: "DP-1",
        exitingScreenName: "", mode: "banner" }, "DP-1"),
    reducedMotion: false, contextId: "critical:40" });
dp1State = rules.complete(dp1Open.state, dp1Open.state.token).state;
const dp1Pending = ownership.compactExitPending({ ownerScreenName: "DP-1",
    exitingScreenName: "", mode: "compact", generation: 41 },
"DP-1", "DP-1", 40, 0);
let dp1Close = rules.transition(dp1State, { mode: "compact", generation: 41,
    transitionOwner: dp1Pending, reducedMotion: false,
    visual: { opacity: 1, scale: 1, y: 0 } });
assert.deepEqual(plain(dp1Close.effects), [{
    type: "animate", phase: "closing", token: 2, generation: 41,
    from: { opacity: 1, scale: 1, y: 0 },
    to: { opacity: 0, scale: 0.96, y: -8 },
    duration: { opacity: 120, scale: 130, y: 130 },
}]);
let dp1Completion = rules.complete(dp1Close.state, dp1Close.state.token);
assert.deepEqual(plain(dp1Completion.effects), [
    { type: "normalize", opacity: 0, scale: 0.96, y: -8 },
    { type: "emit-completion", generation: 41 },
]);
assert.deepEqual(plain(rules.complete(dp1Completion.state, 2).effects), []);
assert.equal(ownership.compactExitPending({ ownerScreenName: "DP-1",
    exitingScreenName: "", mode: "compact", generation: 41 },
"DP-1", "DP-1", 40, 41), false);

const dp2State = rules.initialState();
const dp2Pending = ownership.compactExitPending({ ownerScreenName: "DP-1",
    exitingScreenName: "", mode: "compact", generation: 41 },
"DP-2", "", 0, 0);
const dp2Close = rules.transition(dp2State, { mode: "compact", generation: 41,
    transitionOwner: dp2Pending, reducedMotion: false,
    visual: { opacity: 1, scale: 1, y: 0 } });
assert.equal(dp2Pending, false);
assert.equal(dp2Close.state, dp2State);
assert.deepEqual(plain(dp2Close.effects), []);
console.log("PASS composed DP-1 compact exit completes once while DP-2 stays inactive");

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
    mode: "banner", generation: 5, transitionOwner: true, reducedMotion: false,
    visual: { opacity: 0.2, scale: 0.955, y: -8 }, contextId: "critical:2",
});
state = result.state;
assert.equal(state.phase, "opening");
assert.equal(state.token, openingToken);
assert.equal(state.generation, 5);
assert.equal(state.presentedContextId, "critical:2");
assert.deepEqual(plain(result.effects), []);
result = rules.complete(state, openingToken);
state = result.state;
assert.deepEqual(plain(result.effects), [
    { type: "emit-completion", generation: 5 },
]);
assert.deepEqual(plain(rules.complete(state, openingToken).effects), []);
console.log("PASS same-mode generation rebase preserves entrance and completes newest once");

result = rules.transition(state, {
    mode: "banner", generation: 6, transitionOwner: true, reducedMotion: false,
    visual: { opacity: 1, scale: 1, y: 0 }, contextId: "critical:3",
});
state = result.state;
assert.equal(state.phase, "idle");
assert.equal(state.token, openingToken);
assert.equal(state.generation, 6);
assert.equal(state.presentedContextId, "critical:3");
assert.deepEqual(plain(result.effects), []);
console.log("PASS same-mode idle generation rebase preserves visible popup");

result = rules.transition(state, {
    mode: "expanded", generation: 7, transitionOwner: true, reducedMotion: false,
    visual: { opacity: 0.43, scale: 0.972, y: -5 }, contextId: "approval:1",
});
state = result.state;
assert.equal(state.presentedMode, "expanded");
assert.equal(state.presentedContextId, "approval:1");
assert.deepEqual(plain(result.effects), [
    { type: "complete", token: 2, generation: 7 },
]);
assert.deepEqual(plain(rules.complete(state, 1).effects), [],
    "superseded opening callbacks must be stale");
result = rules.complete(state, 2);
state = result.state;
assert.deepEqual(plain(result.effects), [{ type: "emit-completion", generation: 7 }]);
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
