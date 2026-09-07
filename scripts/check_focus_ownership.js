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

let diagnosticLeaseState = diagnostics.initial();
diagnosticLeaseState = diagnostics.transition(
    diagnosticLeaseState, "center:DP-1", true, 100, "center-instance-old");
diagnosticLeaseState = diagnostics.transition(
    diagnosticLeaseState, "center:DP-1", false, 110, "center-instance-old");
diagnosticLeaseState = diagnostics.transition(
    diagnosticLeaseState, "center:DP-1", true, 120, "center-instance-new");
const diagnosticNewInstance = diagnosticLeaseState;
assert.equal(diagnosticLeaseState.owner, "center:DP-1");
assert.equal(diagnosticLeaseState.lease, "center-instance-new");
assert.strictEqual(diagnostics.transition(
    diagnosticLeaseState, "center:DP-1", false, 130, "center-instance-old"),
    diagnosticNewInstance,
    "stale same-ID destruction cannot clear the newer diagnostic lease holder");
const diagnosticDuplicate = diagnostics.transition(
    diagnosticLeaseState, "center:DP-1", true, 140, "center-instance-duplicate");
assert.equal(diagnosticDuplicate.owner, "center:DP-1");
assert.equal(diagnosticDuplicate.lease, "center-instance-new");
assert.equal(diagnosticDuplicate.violation,
    "exclusive-focus-conflict:center:DP-1:center:DP-1",
    "overlapping same-ID diagnostic leases must remain conflict-visible");

let state = arbiter.initial();
assert.deepEqual(plain(state), {
    owner: "", pendingOwner: "", generation: 0,
    phase: "idle", shouldSchedule: false, violation: "",
});
assert.equal(Object.isFrozen(state), true, "initial snapshots must be frozen");

state = arbiter.request(state, "edge-menu:DP-1", "edge-instance-a");
assert.deepEqual(plain(state), {
    owner: "edge-menu:DP-1", pendingOwner: "", generation: 1,
    phase: "owned", shouldSchedule: false, violation: "",
});
assert.equal(Object.isFrozen(state), true, "granted snapshots must be frozen");
assert.equal(state.ownerLease, "edge-instance-a");

const sameOwner = arbiter.request(state, " edge-menu:DP-1 ", "edge-instance-a");
assert.deepEqual(plain(sameOwner), plain(state),
    "a current-owner request is idempotent after owner normalization");

state = arbiter.request(state, "center:DP-1", "center-instance-a");
assert.equal(state.owner, "");
assert.equal(state.pendingOwner, "center:DP-1");
assert.equal(state.pendingLease, "center-instance-a");
assert.equal(state.phase, "releasing");
assert.equal(state.shouldSchedule, true);
const centerGeneration = state.generation;

state = arbiter.request(state, "overlay:spotlight:DP-1", "spotlight-instance-a");
assert.equal(state.owner, "");
assert.equal(state.pendingOwner, "overlay:spotlight:DP-1");
assert.equal(state.pendingLease, "spotlight-instance-a");
assert.equal(state.generation, centerGeneration + 1);
assert.equal(state.phase, "releasing");
assert.equal(state.shouldSchedule, true);
assert.strictEqual(arbiter.grantPending(state, centerGeneration, "center-instance-a"), state,
    "a stale generation must return the exact releasing state unchanged");
for (const staleToken of [state.generation + 0.5, Number.NaN,
        Number.POSITIVE_INFINITY, Number.MAX_SAFE_INTEGER + 1, "" + state.generation]) {
    assert.strictEqual(arbiter.grantPending(state, staleToken, "spotlight-instance-a"), state,
        "non-exact callback generations must fail closed unchanged");
}
state = arbiter.grantPending(state, state.generation, "spotlight-instance-a");
assert.equal(state.owner, "overlay:spotlight:DP-1");
assert.equal(state.ownerLease, "spotlight-instance-a");
assert.equal(state.pendingOwner, "");
assert.equal(state.phase, "owned");
assert.equal(state.shouldSchedule, false);

const staleRelease = arbiter.withdraw(state, "center:DP-1", "center-instance-a");
assert.equal(staleRelease.owner, "overlay:spotlight:DP-1",
    "a stale release cannot clear a newer owner");
const currentWithdrawal = arbiter.withdraw(state, "overlay:spotlight:DP-1", "spotlight-instance-a");
assert.equal(currentWithdrawal.phase, "releasing");
assert.equal(arbiter.grantPending(
    currentWithdrawal, currentWithdrawal.generation, "").phase, "idle");

let duplicate = arbiter.initial();
duplicate = arbiter.request(duplicate, "center:DP-1", "center-instance-old");
duplicate = arbiter.request(duplicate, "center:DP-1", "center-instance-new");
const duplicateGeneration = duplicate.generation;
assert.equal(duplicate.owner, "",
    "a newer duplicate logical owner must revoke the old instance before grant");
assert.equal(duplicate.pendingOwner, "center:DP-1");
assert.equal(duplicate.pendingLease, "center-instance-new");
assert.strictEqual(arbiter.withdraw(
    duplicate, "center:DP-1", "center-instance-old"), duplicate,
    "an old same-logical-ID instance cannot withdraw the newer pending instance");
duplicate = arbiter.grantPending(duplicate, duplicateGeneration, "center-instance-new");
assert.equal(duplicate.owner, "center:DP-1");
assert.equal(duplicate.ownerLease, "center-instance-new");
assert.strictEqual(arbiter.withdraw(
    duplicate, "center:DP-1", "center-instance-old"), duplicate,
    "an old same-logical-ID instance cannot withdraw the newer grant");

const nonCanonicalState = {
    owner: "center:DP-1", ownerLease: "center-instance-new",
    pendingOwner: "", pendingLease: "", generation: 1,
    phase: "owned", shouldSchedule: false, violation: "",
};
const canonicalPassThrough = arbiter.withdraw(
    nonCanonicalState, "other:DP-1", "other-instance");
assert.notStrictEqual(canonicalPassThrough, nonCanonicalState,
    "external state must be copied into the canonical snapshot boundary");
assert.equal(Object.isFrozen(canonicalPassThrough), true);
assert.strictEqual(arbiter.withdraw(
    canonicalPassThrough, "other:DP-1", "other-instance"), canonicalPassThrough,
    "canonical pass-through state may preserve identity");
assert.strictEqual(arbiter.grantPending(
    canonicalPassThrough, 0, "center-instance-new"), canonicalPassThrough,
    "a stale grant must preserve the complete canonical state");

let closeThenOpen = arbiter.initial();
closeThenOpen = arbiter.request(closeThenOpen, "edge-menu:DP-1:input", "edge-instance-b");
closeThenOpen = arbiter.withdraw(closeThenOpen, "edge-menu:DP-1:input", "edge-instance-b");
assert.deepEqual(plain(closeThenOpen), {
    owner: "", pendingOwner: "", generation: 2,
    phase: "releasing", shouldSchedule: true, violation: "",
}, "withdrawing the current owner must enter an ownerless cooldown");
const releaseGeneration = closeThenOpen.generation;
closeThenOpen = arbiter.request(closeThenOpen, "center:DP-1", "center-instance-b");
assert.deepEqual(plain(closeThenOpen), {
    owner: "", pendingOwner: "center:DP-1", generation: releaseGeneration,
    phase: "releasing", shouldSchedule: true, violation: "",
}, "a request during cooldown must remain ownerless until the scheduled grant");
closeThenOpen = arbiter.grantPending(closeThenOpen, releaseGeneration, "center-instance-b");
assert.equal(closeThenOpen.owner, "center:DP-1");
assert.equal(closeThenOpen.phase, "owned");

let noSuccessor = arbiter.initial();
noSuccessor = arbiter.request(noSuccessor, "settings:DP-1", "settings-instance-a");
noSuccessor = arbiter.withdraw(noSuccessor, "settings:DP-1", "settings-instance-a");
assert.equal(noSuccessor.phase, "releasing",
    "a release without a known successor must still fail closed for one tick");
noSuccessor = arbiter.grantPending(noSuccessor, noSuccessor.generation, "");
assert.deepEqual(plain(noSuccessor), {
    owner: "", pendingOwner: "", generation: 2,
    phase: "idle", shouldSchedule: false, violation: "",
}, "a no-successor release must settle to idle after its barrier");

const blankRequest = arbiter.request(state, "  ", "spotlight-instance-a");
assert.equal(blankRequest.owner, state.owner, "blank requests cannot replace an owner");
assert.equal(blankRequest.pendingOwner, state.pendingOwner);
assert.equal(blankRequest.generation, state.generation);
assert.equal(blankRequest.violation, "missing-focus-owner");
assert.equal(Object.isFrozen(blankRequest), true);

const blankWithdrawal = arbiter.withdraw(state, "\t", "spotlight-instance-a");
assert.equal(blankWithdrawal.owner, state.owner, "blank withdrawals cannot release an owner");
assert.equal(blankWithdrawal.generation, state.generation);
assert.equal(blankWithdrawal.violation, "missing-focus-owner");
const blankLeaseRequest = arbiter.request(arbiter.initial(), "center:DP-1", " ");
assert.equal(blankLeaseRequest.owner, "");
assert.equal(blankLeaseRequest.generation, 0);
assert.equal(blankLeaseRequest.violation, "missing-focus-lease");

let replacement = arbiter.initial();
replacement = arbiter.request(replacement, "center:DP-1", "center-instance-c");
replacement = arbiter.request(replacement, "overlay:spotlight:DP-1", "spotlight-instance-b");
const spotlightGeneration = replacement.generation;
replacement = arbiter.request(replacement, "settings:DP-1", "settings-instance-b");
const settingsGeneration = replacement.generation;
assert.equal(replacement.pendingOwner, "settings:DP-1",
    "the newest pending request must replace Spotlight");
assert.strictEqual(arbiter.grantPending(
    replacement, spotlightGeneration, "spotlight-instance-b"), replacement,
    "Spotlight's stale generation must return the exact state unchanged");
replacement = arbiter.grantPending(replacement, settingsGeneration, "settings-instance-b");
assert.equal(replacement.owner, "settings:DP-1");
assert.equal(arbiter.withdraw(replacement, "overlay:spotlight:DP-1", "spotlight-instance-b").owner,
    "settings:DP-1");
replacement = arbiter.withdraw(replacement, "settings:DP-1", "settings-instance-b");
assert.deepEqual(plain(replacement), {
    owner: "", pendingOwner: "", generation: settingsGeneration + 1,
    phase: "releasing", shouldSchedule: true, violation: "",
});
replacement = arbiter.grantPending(replacement, replacement.generation, "");
assert.equal(replacement.phase, "idle");

let pending = arbiter.initial();
pending = arbiter.request(pending, "center:DP-1", "center-instance-d");
pending = arbiter.request(pending, "overlay:spotlight:DP-1", "spotlight-instance-c");
pending = arbiter.withdraw(pending, "overlay:spotlight:DP-1", "spotlight-instance-c");
assert.deepEqual(plain(pending), {
    owner: "", pendingOwner: "", generation: 2,
    phase: "releasing", shouldSchedule: true, violation: "",
}, "withdrawing the pending owner retains the ownerless handoff barrier");
assert.equal(arbiter.grantPending(pending, 2, "").phase, "idle");

let samePending = arbiter.initial();
samePending = arbiter.request(samePending, "center:DP-1", "center-instance-e");
samePending = arbiter.request(samePending, "overlay:spotlight:DP-1", "spotlight-instance-d");
const unchangedPending = arbiter.request(
    samePending, "overlay:spotlight:DP-1", "spotlight-instance-d");
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
applyScheduled(arbiter.request(scheduledState, "center:DP-1", "center-instance-f"));
applyScheduled(arbiter.request(scheduledState, "overlay:spotlight:DP-1", "spotlight-instance-e"));
applyScheduled(arbiter.request(scheduledState, "overlay:spotlight:DP-1", "spotlight-instance-e"));
assert.deepEqual(scheduledCallbacks, [2],
    "one unchanged pending request must leave exactly one callback outstanding");

let overlayReplacement = arbiter.initial();
overlayReplacement = arbiter.request(
    overlayReplacement, "overlay:spotlight:DP-1", "overlay-instance-a");
overlayReplacement = arbiter.request(
    overlayReplacement, "overlay:window-switcher:DP-1", "overlay-instance-a");
assert.equal(overlayReplacement.owner, "",
    "same-window overlay replacement must revoke the previous logical grant");
assert.equal(overlayReplacement.pendingOwner, "overlay:window-switcher:DP-1");
assert.equal(overlayReplacement.phase, "releasing");

let edgeReplacement = arbiter.initial();
edgeReplacement = arbiter.request(
    edgeReplacement, "edge-menu:DP-1:menu:input", "edge-instance-c");
edgeReplacement = arbiter.request(
    edgeReplacement, "edge-menu:DP-1:surface:system-tray:DP-1:audio", "edge-instance-c");
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
assert.match(arbiterQml, /function newLease\(/,
    "FocusArbiter must issue unique requester leases");
assert.match(arbiterQml,
    /FocusArbiterRules\.request\(root\.state, ownerId, lease\)/,
    "FocusArbiter must pass requester leases into request rules");
assert.match(arbiterQml,
    /FocusArbiterRules\.withdraw\(root\.state, ownerId, lease\)/,
    "FocusArbiter must pass requester leases into withdraw rules");
assert.match(arbiterQml,
    /FocusArbiterRules\.grantPending\([\s\S]{0,100}root\.state, generation, root\.state\.pendingLease\)/,
    "FocusArbiter must pass requester leases into grant rules");
assert.match(arbiterQml,
    /function granted\(ownerId: string, lease: string\)/,
    "FocusArbiter granted checks must include requester leases");
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
];

for (const contract of interactiveWindows) {
    const text = fs.readFileSync(path.join(root, "Titonium", contract.relative), "utf8");
    assert.match(text, /property string focusOwnerId:/,
        `${contract.relative} lacks a stable focusOwnerId`);
    assert.match(text, /property string focusLease:/,
        `${contract.relative} lacks a unique requester lease`);
    assert.match(text, /FocusArbiter\.newLease\(/,
        `${contract.relative} must allocate its requester lease from FocusArbiter`);
    assert.ok(text.includes(contract.ownerPrefix),
        `${contract.relative} focusOwnerId lacks its stable family prefix`);
    assert.match(text, /readonly property bool wantsInteractiveFocus:/,
        `${contract.relative} lacks wantsInteractiveFocus`);
    assert.match(text, contract.wants,
        `${contract.relative} changed its logical focus condition`);
    assert.match(text,
        /FocusArbiter\.request\(window\.focusOwnerId,\s*window\.focusLease,\s*window\.wantsInteractiveFocus\)/,
        `${contract.relative} does not submit focus desire to FocusArbiter`);
    assert.match(text, /Component\.onDestruction:[\s\S]*FocusArbiter\.withdraw\(window\.focusOwnerId,\s*window\.focusLease\)/,
        `${contract.relative} does not withdraw focus on destruction`);
    assert.match(text,
        /WlrLayershell\.keyboardFocus:[\s\S]{0,180}FocusArbiter\.granted\(window\.focusOwnerId,\s*window\.focusLease\)[\s\S]{0,180}WlrKeyboardFocus\./,
        `${contract.relative} does not gate layer-shell focus through FocusArbiter`);
    assert.ok(text.includes(`WlrKeyboardFocus.${contract.focusMode}`),
        `${contract.relative} must preserve ${contract.focusMode} focus semantics`);
    assert.match(text, /readonly property bool effectiveInteractiveFocus:/,
        `${contract.relative} lacks an effective grant projection`);
    assert.match(text,
        /onEffectiveInteractiveFocusChanged:[\s\S]{0,260}FocusDiagnostics\.observe\(/,
        `${contract.relative} diagnostics must observe effective grant changes`);
    assert.match(text,
        /FocusDiagnostics\.observe\([\s\S]{0,180}window\.focusLease/,
        `${contract.relative} diagnostics must pass its matching requester lease`);
    assert.equal(text.includes("FocusDiagnostics.observe(window.focusLease"), false,
        `${contract.relative} diagnostics must retain stable logical owner IDs`);
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

const diagnosticsQml = fs.readFileSync(
    path.join(root, "Titonium/Core/Surfaces/FocusDiagnostics.qml"), "utf8");
assert.match(diagnosticsQml, /property string holderLease:/,
    "FocusDiagnostics must retain the lease of its current diagnostic holder");
assert.match(diagnosticsQml,
    /function observe\(ownerId: string, lease: string, active: bool, metadata: var\)/,
    "FocusDiagnostics observe must accept a requester lease");
assert.match(diagnosticsQml,
    /holderOwnerId[\s\S]{0,500}holderLease[\s\S]{0,500}return;/,
    "FocusDiagnostics must ignore stale lease cleanup");

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
