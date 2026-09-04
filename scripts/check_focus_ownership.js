#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");

function loadRules(relative) {
    const rulesPath = path.join(root, relative);
    const source = fs.readFileSync(rulesPath, "utf8")
        .replace(/^\.pragma library\s*\n/, "");
    const context = vm.createContext({ Object, String, Number, Math });
    vm.runInContext(source, context, { filename: rulesPath });
    return context;
}

const arbiter = loadRules("Titonium/Core/Surfaces/FocusArbiterRules.js");
const diagnostics = loadRules("Titonium/Core/Surfaces/FocusOwnershipRules.js");
const plain = value => JSON.parse(JSON.stringify(value));

let diagnosticState = diagnostics.initial();
diagnosticState = diagnostics.transition(diagnosticState, "overlay:spotlight", true, 100);
assert.deepEqual(plain(diagnosticState), {
    owner: "overlay:spotlight", acquiredAt: 100, releasedAt: 0, violation: "",
});
const diagnosticConflict = diagnostics.transition(
    diagnosticState, "center:expanded", true, 120);
assert.equal(diagnosticConflict.owner, "overlay:spotlight");
assert.equal(diagnosticConflict.violation,
    "exclusive-focus-conflict:overlay:spotlight:center:expanded");
diagnosticState = diagnostics.transition(
    diagnosticState, "overlay:spotlight", false, 150);
assert.deepEqual(plain(diagnosticState), {
    owner: "", acquiredAt: 0, releasedAt: 150, violation: "",
});

let state = arbiter.initial();
assert.deepEqual(plain(state), {
    owner: "", pendingOwner: "", generation: 0,
    phase: "idle", shouldSchedule: false, violation: "",
});
assert.equal(Object.isFrozen(state), true, "initial snapshots must be frozen");

state = arbiter.request(state, "edge-menu:DP-1");
assert.deepEqual(plain(state), {
    owner: "edge-menu:DP-1", pendingOwner: "", generation: 1,
    phase: "owned", shouldSchedule: false, violation: "",
});
assert.equal(Object.isFrozen(state), true, "granted snapshots must be frozen");

const sameOwner = arbiter.request(state, " edge-menu:DP-1 ");
assert.deepEqual(plain(sameOwner), plain(state),
    "a current-owner request is idempotent after owner normalization");

state = arbiter.request(state, "center:DP-1");
assert.equal(state.owner, "");
assert.equal(state.pendingOwner, "center:DP-1");
assert.equal(state.phase, "releasing");
assert.equal(state.shouldSchedule, true);
const centerGeneration = state.generation;

state = arbiter.request(state, "overlay:spotlight:DP-1");
assert.equal(state.owner, "");
assert.equal(state.pendingOwner, "overlay:spotlight:DP-1");
assert.equal(state.generation, centerGeneration + 1);
assert.equal(state.phase, "releasing");
assert.equal(state.shouldSchedule, true);
assert.strictEqual(arbiter.grantPending(state, centerGeneration), state,
    "a stale generation must return the exact releasing state unchanged");
for (const staleToken of [state.generation + 0.5, Number.NaN,
        Number.POSITIVE_INFINITY, Number.MAX_SAFE_INTEGER + 1, "" + state.generation]) {
    assert.strictEqual(arbiter.grantPending(state, staleToken), state,
        "non-exact callback generations must fail closed unchanged");
}
state = arbiter.grantPending(state, state.generation);
assert.equal(state.owner, "overlay:spotlight:DP-1");
assert.equal(state.pendingOwner, "");
assert.equal(state.phase, "owned");
assert.equal(state.shouldSchedule, false);

const staleRelease = arbiter.withdraw(state, "center:DP-1");
assert.equal(staleRelease.owner, "overlay:spotlight:DP-1",
    "a stale release cannot clear a newer owner");
const currentWithdrawal = arbiter.withdraw(state, "overlay:spotlight:DP-1");
assert.equal(currentWithdrawal.phase, "releasing");
assert.equal(arbiter.grantPending(
    currentWithdrawal, currentWithdrawal.generation).phase, "idle");

let closeThenOpen = arbiter.initial();
closeThenOpen = arbiter.request(closeThenOpen, "edge-menu:DP-1:input");
closeThenOpen = arbiter.withdraw(closeThenOpen, "edge-menu:DP-1:input");
assert.deepEqual(plain(closeThenOpen), {
    owner: "", pendingOwner: "", generation: 2,
    phase: "releasing", shouldSchedule: true, violation: "",
}, "withdrawing the current owner must enter an ownerless cooldown");
const releaseGeneration = closeThenOpen.generation;
closeThenOpen = arbiter.request(closeThenOpen, "center:DP-1");
assert.deepEqual(plain(closeThenOpen), {
    owner: "", pendingOwner: "center:DP-1", generation: releaseGeneration,
    phase: "releasing", shouldSchedule: true, violation: "",
}, "a request during cooldown must remain ownerless until the scheduled grant");
closeThenOpen = arbiter.grantPending(closeThenOpen, releaseGeneration);
assert.equal(closeThenOpen.owner, "center:DP-1");
assert.equal(closeThenOpen.phase, "owned");

let noSuccessor = arbiter.initial();
noSuccessor = arbiter.request(noSuccessor, "settings:DP-1");
noSuccessor = arbiter.withdraw(noSuccessor, "settings:DP-1");
assert.equal(noSuccessor.phase, "releasing",
    "a release without a known successor must still fail closed for one tick");
noSuccessor = arbiter.grantPending(noSuccessor, noSuccessor.generation);
assert.deepEqual(plain(noSuccessor), {
    owner: "", pendingOwner: "", generation: 2,
    phase: "idle", shouldSchedule: false, violation: "",
}, "a no-successor release must settle to idle after its barrier");

const blankRequest = arbiter.request(state, "  ");
assert.equal(blankRequest.owner, state.owner, "blank requests cannot replace an owner");
assert.equal(blankRequest.pendingOwner, state.pendingOwner);
assert.equal(blankRequest.generation, state.generation);
assert.equal(blankRequest.violation, "missing-focus-owner");
assert.equal(Object.isFrozen(blankRequest), true);

const blankWithdrawal = arbiter.withdraw(state, "\t");
assert.equal(blankWithdrawal.owner, state.owner, "blank withdrawals cannot release an owner");
assert.equal(blankWithdrawal.generation, state.generation);
assert.equal(blankWithdrawal.violation, "missing-focus-owner");

let replacement = arbiter.initial();
replacement = arbiter.request(replacement, "center:DP-1");
replacement = arbiter.request(replacement, "overlay:spotlight:DP-1");
const spotlightGeneration = replacement.generation;
replacement = arbiter.request(replacement, "settings:DP-1");
const settingsGeneration = replacement.generation;
assert.equal(replacement.pendingOwner, "settings:DP-1",
    "the newest pending request must replace Spotlight");
assert.strictEqual(arbiter.grantPending(replacement, spotlightGeneration), replacement,
    "Spotlight's stale generation must return the exact state unchanged");
replacement = arbiter.grantPending(replacement, settingsGeneration);
assert.equal(replacement.owner, "settings:DP-1");
assert.equal(arbiter.withdraw(replacement, "overlay:spotlight:DP-1").owner,
    "settings:DP-1");
replacement = arbiter.withdraw(replacement, "settings:DP-1");
assert.deepEqual(plain(replacement), {
    owner: "", pendingOwner: "", generation: settingsGeneration + 1,
    phase: "releasing", shouldSchedule: true, violation: "",
});
replacement = arbiter.grantPending(replacement, replacement.generation);
assert.equal(replacement.phase, "idle");

let pending = arbiter.initial();
pending = arbiter.request(pending, "center:DP-1");
pending = arbiter.request(pending, "overlay:spotlight:DP-1");
pending = arbiter.withdraw(pending, "overlay:spotlight:DP-1");
assert.deepEqual(plain(pending), {
    owner: "", pendingOwner: "", generation: 2,
    phase: "releasing", shouldSchedule: true, violation: "",
}, "withdrawing the pending owner retains the ownerless handoff barrier");
assert.equal(arbiter.grantPending(pending, 2).phase, "idle");

let samePending = arbiter.initial();
samePending = arbiter.request(samePending, "center:DP-1");
samePending = arbiter.request(samePending, "overlay:spotlight:DP-1");
const unchangedPending = arbiter.request(samePending, "overlay:spotlight:DP-1");
assert.strictEqual(unchangedPending, samePending,
    "an unchanged pending request must be idempotent and preserve its generation");

let scheduledState = arbiter.initial();
let scheduledGeneration = -1;
const scheduledCallbacks = [];
function applyScheduled(next) {
    if (next === scheduledState)
        return;
    scheduledState = next;
    if (next.shouldSchedule && scheduledGeneration !== next.generation) {
        scheduledGeneration = next.generation;
        scheduledCallbacks.push(next.generation);
    }
}
applyScheduled(arbiter.request(scheduledState, "center:DP-1"));
applyScheduled(arbiter.request(scheduledState, "overlay:spotlight:DP-1"));
applyScheduled(arbiter.request(scheduledState, "overlay:spotlight:DP-1"));
assert.deepEqual(scheduledCallbacks, [2],
    "one unchanged pending request must leave exactly one callback outstanding");

let overlayReplacement = arbiter.initial();
overlayReplacement = arbiter.request(
    overlayReplacement, "overlay:spotlight:DP-1");
overlayReplacement = arbiter.request(
    overlayReplacement, "overlay:window-switcher:DP-1");
assert.equal(overlayReplacement.owner, "",
    "same-window overlay replacement must revoke the previous logical grant");
assert.equal(overlayReplacement.pendingOwner, "overlay:window-switcher:DP-1");
assert.equal(overlayReplacement.phase, "releasing");

let edgeReplacement = arbiter.initial();
edgeReplacement = arbiter.request(
    edgeReplacement, "edge-menu:DP-1:menu:input");
edgeReplacement = arbiter.request(
    edgeReplacement, "edge-menu:DP-1:surface:system-tray:DP-1:audio");
assert.equal(edgeReplacement.owner, "",
    "same-window Edge Menu replacement must revoke the previous logical grant");
assert.equal(edgeReplacement.pendingOwner,
    "edge-menu:DP-1:surface:system-tray:DP-1:audio");
assert.equal(edgeReplacement.phase, "releasing");

const arbiterPath = path.join(root, "Titonium/Core/Surfaces/FocusArbiter.qml");
assert.equal(fs.existsSync(arbiterPath), true, "FocusArbiter.qml must exist");
const arbiterQml = fs.readFileSync(arbiterPath, "utf8");
assert.match(arbiterQml, /pragma Singleton/,
    "FocusArbiter must be a singleton");
assert.match(arbiterQml,
    /import\s+"FocusArbiterRules\.js"\s+as\s+FocusArbiterRules/,
    "FocusArbiter must consume the pure rules module");
for (const projection of ["owner", "pendingOwner", "phase", "generation"])
    assert.match(arbiterQml, new RegExp(`readonly property \\w+ ${projection}:`),
        `FocusArbiter must project readonly ${projection}`);
for (const method of ["request", "withdraw", "granted"])
    assert.match(arbiterQml, new RegExp(`function ${method}\\(`),
        `FocusArbiter must expose ${method}()`);
assert.equal((arbiterQml.match(/Qt\.callLater/g) || []).length, 1,
    "FocusArbiter must own exactly one event-loop handoff");
assert.match(arbiterQml, /scheduledGeneration/,
    "FocusArbiter must guard duplicate scheduling by generation");
assert.match(arbiterQml, /if \(next === root\.state\)\s*return;/,
    "FocusArbiter must ignore unchanged snapshots before scheduling");
assert.match(arbiterQml,
    /next\.shouldSchedule\s*&&\s*root\.scheduledGeneration !== next\.generation/,
    "FocusArbiter must queue at most one callback for a generation");

const interactiveWindows = [
    {
        relative: "Core/Surfaces/OverlayHost.qml",
        ownerPrefix: "overlay:",
        wants: /ownsOverlaySurface[\s\S]*descriptor\.keyboardFocus === "exclusive"/,
        focusMode: "Exclusive",
    },
    {
        relative: "Core/Surfaces/Center/CenterOverlayWindow.qml",
        ownerPrefix: "center:",
        wants: /ownsOverlay[\s\S]*viewState\.focusPolicy === "exclusive"/,
        focusMode: "Exclusive",
    },
    {
        relative: "Bar/right/EdgeMenuWindow.qml",
        ownerPrefix: "edge-menu:",
        wants: /wantsInteractiveFocus:\s*window\.ownsMenu/,
        focusMode: "Exclusive",
    },
    {
        relative: "Settings/SettingsWindow.qml",
        ownerPrefix: "settings:",
        wants: /wantsInteractiveFocus:\s*window\.ownsSettings/,
        focusMode: "Exclusive",
    },
    {
        relative: "AgentApproval/AgentApprovalWindow.qml",
        ownerPrefix: "agent-approval:",
        wants: /!window\.isFileChange\s*&&\s*window\.ownsApproval/,
        focusMode: "OnDemand",
    },
];

for (const contract of interactiveWindows) {
    const text = fs.readFileSync(path.join(root, "Titonium", contract.relative), "utf8");
    assert.match(text, /property string focusOwnerId:/,
        `${contract.relative} lacks a stable focusOwnerId`);
    assert.ok(text.includes(contract.ownerPrefix),
        `${contract.relative} focusOwnerId lacks its stable family prefix`);
    assert.match(text, /readonly property bool wantsInteractiveFocus:/,
        `${contract.relative} lacks wantsInteractiveFocus`);
    assert.match(text, contract.wants,
        `${contract.relative} changed its logical focus condition`);
    assert.match(text,
        /FocusArbiter\.request\(window\.focusOwnerId, window\.wantsInteractiveFocus\)/,
        `${contract.relative} does not submit focus desire to FocusArbiter`);
    assert.match(text, /Component\.onDestruction:[\s\S]*FocusArbiter\.withdraw\(window\.focusOwnerId\)/,
        `${contract.relative} does not withdraw focus on destruction`);
    assert.match(text,
        /WlrLayershell\.keyboardFocus:[\s\S]{0,180}FocusArbiter\.granted\(window\.focusOwnerId\)[\s\S]{0,180}WlrKeyboardFocus\./,
        `${contract.relative} does not gate layer-shell focus through FocusArbiter`);
    assert.ok(text.includes(`WlrKeyboardFocus.${contract.focusMode}`),
        `${contract.relative} must preserve ${contract.focusMode} focus semantics`);
    assert.match(text, /readonly property bool effectiveInteractiveFocus:/,
        `${contract.relative} lacks an effective grant projection`);
    assert.match(text,
        /onEffectiveInteractiveFocusChanged:[\s\S]{0,260}FocusDiagnostics\.observe\(/,
        `${contract.relative} diagnostics must observe effective grant changes`);
}

const overlayHost = fs.readFileSync(
    path.join(root, "Titonium/Core/Surfaces/OverlayHost.qml"), "utf8");
assert.match(overlayHost,
    /readonly property string logicalFocusOwnerId:[\s\S]{0,100}"overlay:"\s*\+\s*SurfaceManager\.ownerId/,
    "OverlayHost logical focus identity must include SurfaceManager.ownerId");
assert.match(overlayHost,
    /onLogicalFocusOwnerIdChanged:[\s\S]{0,180}syncInteractiveFocus\(\)/,
    "OverlayHost must resubmit when its logical owner changes in place");
assert.match(overlayHost, /property string diagnosticFocusOwnerId:/,
    "OverlayHost must retain the identity that actually held its effective grant");
assert.match(overlayHost,
    /onEffectiveInteractiveFocusChanged:[\s\S]{0,700}FocusDiagnostics\.observe\(window\.diagnosticFocusOwnerId/,
    "OverlayHost must release the identity that actually held its effective grant");

const edgeMenu = fs.readFileSync(
    path.join(root, "Titonium/Bar/right/EdgeMenuWindow.qml"), "utf8");
assert.match(edgeMenu,
    /readonly property string logicalFocusOwnerId:[\s\S]{0,500}RightPillCoordinator\.menuSource/,
    "EdgeMenuWindow logical focus identity must include the active menu source");
assert.match(edgeMenu,
    /readonly property string logicalFocusOwnerId:[\s\S]{0,500}RightPillCoordinator\.connectedOwnerId/,
    "EdgeMenuWindow logical focus identity must include the connected surface owner");
assert.match(edgeMenu,
    /onLogicalFocusOwnerIdChanged:[\s\S]{0,180}syncInteractiveFocus\(\)/,
    "EdgeMenuWindow must resubmit when its logical owner changes in place");
assert.match(edgeMenu, /property string diagnosticFocusOwnerId:/,
    "EdgeMenuWindow must retain the identity that actually held its effective grant");
assert.match(edgeMenu,
    /onEffectiveInteractiveFocusChanged:[\s\S]{0,700}FocusDiagnostics\.observe\(window\.diagnosticFocusOwnerId/,
    "EdgeMenuWindow must release the identity that actually held its effective grant");

const qmldir = fs.readFileSync(
    path.join(root, "Titonium/Core/Surfaces/qmldir"), "utf8");
assert.ok(qmldir.includes("singleton FocusArbiter 1.0 FocusArbiter.qml"),
    "Core Surfaces qmldir must export FocusArbiter");

for (const relative of ["Titonium/Orchestration/SurfaceRouter.qml",
        "Titonium/Bar/right/RightPillCoordinator.qml"]) {
    const text = fs.readFileSync(path.join(root, relative), "utf8");
    assert.equal(text.includes("Qt.callLater"), false,
        `${relative} must not schedule a focus handoff`);
}

const serviceRoot = path.join(root, "Titonium/Services");
const serviceFiles = [];
function collectQml(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
        const absolute = path.join(directory, entry.name);
        if (entry.isDirectory())
            collectQml(absolute);
        else if (entry.name.endsWith(".qml"))
            serviceFiles.push(absolute);
    }
}
collectQml(serviceRoot);
for (const absolute of serviceFiles) {
    const text = fs.readFileSync(absolute, "utf8");
    assert.equal(/FocusArbiter|grantPending|focusHandoff/.test(text), false,
        `${path.relative(root, absolute)} must not own focus handoff scheduling`);
}

console.log("PASS exclusive focus arbiter state and QML integration contracts");
