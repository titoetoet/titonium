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
assert.equal(arbiter.withdraw(state, "overlay:spotlight:DP-1").phase, "idle");

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
    owner: "", pendingOwner: "", generation: settingsGeneration,
    phase: "idle", shouldSchedule: false, violation: "",
});

let pending = arbiter.initial();
pending = arbiter.request(pending, "center:DP-1");
pending = arbiter.request(pending, "overlay:spotlight:DP-1");
pending = arbiter.withdraw(pending, "overlay:spotlight:DP-1");
assert.deepEqual(plain(pending), {
    owner: "", pendingOwner: "", generation: 2,
    phase: "idle", shouldSchedule: false, violation: "",
}, "withdrawing the pending owner cancels the handoff");
assert.equal(arbiter.grantPending(pending, 2).phase, "idle");

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
