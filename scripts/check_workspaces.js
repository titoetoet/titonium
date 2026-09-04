#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const helperPath = path.join(root, "Titonium", "Services", "Hyprland", "WorkspaceRules.js");
const identityPath = path.join(root, "Titonium", "Services", "Applications", "AppIdentityRules.js");
const visualPath = path.join(root, "Titonium", "Bar", "widgets", "WorkspaceVisualRules.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL Workspace rules are missing");
    process.exit(1);
}
if (!fs.existsSync(visualPath)) {
    console.error("FAIL Workspace visual rules are missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({ Math, Number, Object, Array, isFinite });
vm.runInContext(source, context, { filename: helperPath });
const visualSource = fs.readFileSync(visualPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const visual = vm.createContext({ Math, Number, Array });
vm.runInContext(visualSource, visual, { filename: visualPath });
const plain = value => JSON.parse(JSON.stringify(value));
const identitySource = fs.readFileSync(identityPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const identity = vm.createContext({ Object, Array, String });
vm.runInContext(identitySource, identity, { filename: identityPath });

assert.equal(context.groupStart(1, 5), 1);
assert.equal(context.groupStart(5, 5), 1);
const dp1Monitor = { name: "DP-1", activeWorkspace: { id: 1 } };
const dp3Monitor = { name: "DP-3", activeWorkspace: { id: 2 } };
assert.equal(context.monitorByName([dp3Monitor, dp1Monitor], "DP-1"), dp1Monitor,
    "screen-local state must resolve DP-1 even while DP-3 has global focus");
assert.equal(context.monitorByName({ 0: dp3Monitor, 1: dp1Monitor, length: 2 }, "DP-1"),
    dp1Monitor, "Quickshell's array-like monitor model must resolve by screen name");
dp3Monitor.focused = true;
assert.equal(context.focusedWorkspaceId([dp1Monitor, dp3Monitor], 1), 2,
    "startup focus must come from the monitor focused before Titonium launched");
dp3Monitor.focused = false;
assert.equal(context.focusedWorkspaceId([dp1Monitor, dp3Monitor], 1), 1);
dp1Monitor.focused = true;
assert.equal(context.focusedMonitorWorkspaceId([dp1Monitor, dp3Monitor], "DP-3", 1), 2,
    "the focusedmon name must beat stale per-monitor focused flags during later events");
assert.equal(context.focusedMonitorWorkspaceId([dp1Monitor, dp3Monitor], "missing", 7), 7);
assert.equal(context.focusedWorkspaceEventId("focusedmonv2", ["DP-3", "2"]), 2,
    "mouse-driven monitor focus must use the workspace ID carried by focusedmonv2");
assert.equal(context.focusedWorkspaceEventId("focusedmon", ["DP-1", "1"]), 1,
    "legacy focusedmon must support numeric workspace names");
assert.equal(context.focusedWorkspaceEventId("workspacev2", ["2", "2"]), 2,
    "explicit workspace changes must update the same event-backed focus state");
assert.equal(context.focusedWorkspaceEventId("workspace", ["3"]), 3);
assert.equal(context.monitorByName([dp3Monitor, dp1Monitor], "missing"), null);
assert.equal(context.groupStart(6, 5), 6);
assert.equal(context.groupStart(-1, 5), 1);

const five = context.project(5, 5, [], []);
assert.deepEqual(plain(five.map(item => item.id)), [1, 2, 3, 4, 5]);
assert.deepEqual(plain(five.map(item => item.colorIndex)), [0, 1, 2, 3, 4]);

const projected = context.project(7, 5, [
    { id: 6, occupied: true, urgent: false },
    { id: 7, occupied: true, urgent: false },
    { id: 9, occupied: true, urgent: true },
], [
    { id: "six", workspaceId: 6, icon: "editor", appId: "Code" },
    { id: "recent", workspaceId: 7, icon: "firefox", appId: "Firefox", native: { secret: true } },
    { id: "older", workspaceId: 7, icon: "terminal", appId: "kitty" },
    { id: "duplicate", workspaceId: 7, icon: "firefox-nightly", appId: "firefox" },
    { id: "other", workspaceId: 9, icon: "monitor", appId: "btop" },
    { id: "early-window", workspaceId: 10, icon: "notes", appId: "Notes" },
]);

assert.deepEqual(plain(projected.map(item => item.id)), [6, 7, 8, 9, 10]);
assert.deepEqual(plain(projected[0]), {
    id: 6, active: false, occupied: true, urgent: false,
    apps: [{ appId: "Code", icon: "editor", fallbackIcon: "apps" }], colorIndex: 5,
    rangeStart: 6, rangeEnd: 7,
});
assert.deepEqual(plain(projected[1]), {
    id: 7, active: true, occupied: true, urgent: false,
    apps: [
        { appId: "Firefox", icon: "firefox", fallbackIcon: "apps" },
        { appId: "kitty", icon: "terminal", fallbackIcon: "apps" },
    ],
    colorIndex: 6, rangeStart: 6, rangeEnd: 7,
});
assert.deepEqual(plain(projected[2]), {
    id: 8, active: false, occupied: false, urgent: false,
    apps: [], colorIndex: 7, rangeStart: 0, rangeEnd: 0,
});
assert.equal(projected[3].rangeStart, 9);
assert.equal(projected[3].rangeEnd, 10);
assert.equal(projected[3].urgent, true);
assert.equal(projected[4].occupied, true);
assert.deepEqual(plain(projected[4].apps), [{ appId: "Notes", icon: "notes", fallbackIcon: "apps" }]);
const chatGpt = identity.resolve({
    appId: "", ipcClass: "chatgpt", initialClass: "ChatGPT", title: "ChatGPT"
}, candidate => candidate.toLocaleLowerCase() === "chatgpt"
    ? { id: "chatgpt.desktop", icon: "chatgpt" } : null,
icon => icon === "chatgpt" ? "" : "resolved:" + icon);
assert.deepEqual(plain(chatGpt), {
    appId: "chatgpt", desktopEntryId: "chatgpt.desktop", icon: "", fallbackIcon: "smart_toy"
}, "a ChatGPT-only workspace must retain a semantic fallback when its theme icon is absent");
assert.equal(Object.isFrozen(projected), true);
assert.equal(projected.every(Object.isFrozen), true);
assert.equal(projected.every(item => Object.isFrozen(item.apps)), true);
assert.equal(projected.flatMap(item => item.apps).every(Object.isFrozen), true);
assert.equal(JSON.stringify(projected).includes("native"), false);
assert.equal(JSON.stringify(projected).includes("toplevel"), false);
assert.equal(JSON.stringify(projected).includes("workspace\""), false);

const mutedPalette = ["#233a5e", "#1f4a3b", "#58451d", "#49305f", "#5a2934"];
const activeBlue = "#5b8fce";
assert.equal(visual.occupiedWidth(1, 17, 3), 40);
assert.equal(visual.occupiedWidth(2, 17, 3), 53);
assert.equal(visual.occupiedWidth(3, 17, 3), 73);
assert.equal(visual.pillHeight(false), 24);
assert.equal(visual.pillHeight(true), 24);
assert.equal(visual.slotHeight(), 24);
assert.equal(visual.backgroundColor(0, false, mutedPalette, activeBlue), "#233a5e");
assert.equal(visual.backgroundColor(3, false, mutedPalette, activeBlue), "#49305f");
assert.equal(visual.backgroundColor(3, true, mutedPalette, activeBlue), activeBlue);
assert.equal(visual.backgroundColor(8, true, mutedPalette, activeBlue), activeBlue);
assert.equal(visual.shouldSkipSelectionMove(true, 1, 1, true, false), false,
    "a second icon arriving during animation must resize the active highlight");
assert.equal(visual.shouldSkipSelectionMove(true, 1, 1, true, true), true);
assert.equal(visual.shouldSkipSelectionMove(false, 1, 1, false, true), false);

console.log("PASS workspace projection, muted palette, active-blue highlight and roomy pill fixtures");

const workspacesSource = fs.readFileSync(path.join(root, "Titonium", "Bar", "widgets",
    "Workspaces.qml"), "utf8");
const startSource = fs.readFileSync(path.join(root, "Titonium", "Bar", "islands",
    "StartIsland.qml"), "utf8");
const hyprlandServiceSource = fs.readFileSync(path.join(root, "Titonium", "Services",
    "Hyprland", "HyprlandService.qml"), "utf8");
assert.match(workspacesSource, /readonly property int count: Preferences\.bar\.workspaceCount/);
assert.match(workspacesSource,
    /activeWorkspaceId: HyprlandService\.focusedWorkspaceIdValue/);
assert.match(workspacesSource,
    /workspaceSnapshotForId\(\s*root\.count, root\.activeWorkspaceId\)/);
assert.match(hyprlandServiceSource,
    /target: Hyprland\.monitors[\s\S]*function onValuesChanged\(\): void \{[\s\S]*root\.bootstrapFocusedWorkspace\(\);[\s\S]*root\.recomputeWindows\(\);/,
    "startup focus must resync when the refreshed monitor model becomes available");
assert.match(hyprlandServiceSource,
    /focusedWorkspaceEventId\(event\.name, fields\)[\s\S]*root\.focusedWorkspaceIdValue = eventWorkspaceId/,
    "focusedmon payload must win over a monitor model that updates one event-loop turn later");
assert.match(hyprlandServiceSource,
    /focusedMonitorWorkspaceId\([\s\S]*root\.focusedMonitorName/,
    "later raw events must preserve the workspace selected by focusedmon");
const recomputeBlock = hyprlandServiceSource.slice(
    hyprlandServiceSource.indexOf("function recomputeWindows"),
    hyprlandServiceSource.indexOf("function focusWindow"));
assert.equal(recomputeBlock.includes("root.focusedWorkspaceIdValue ="), false,
    "window recomputation must not overwrite event-backed workspace focus");
assert.equal(workspacesSource.includes("property int count: 5"), false);
assert.equal(startSource.includes("count: 5"), false);
for (const fragment of [
    "id: selectionHighlight",
    "function moveSelectionHighlight(workspaceId: int)",
    "function activateWorkspace(workspaceId: int)",
    "function selectionGeometry(workspaceId: int)",
    "root.moveSelectionHighlight(workspaceId);\n        HyprlandService.activateWorkspace(workspaceId);",
    "readonly property bool visuallyActive:",
    "workspaceItem.modelData.id === root.visualWorkspaceId",
    "visible: workspaceItem.modelData.occupied && !workspaceItem.visuallyActive",
    "onActiveWorkspaceIdChanged:",
    "onTapped: root.activateWorkspace(workspaceItem.modelData.id)",
    "id: selectionMotion",
    "id: stretchPhase",
    "id: settlePhase",
    "Motion.reduced",
]) {
    assert.match(workspacesSource, new RegExp(fragment.replace(/[()]/g, "\\$&")),
        `Workspaces missing shared sliding selection contract: ${fragment}`);
}
assert.equal(workspacesSource.includes("workspaceRepeater.itemAt(index)"), false,
    "selection geometry must not depend on transient Repeater delegates");
assert.equal(workspacesSource.includes("workspaceItem.modelData.active ? 10 : 7"), false,
    "active workspace must not resize its internal marker");
console.log("PASS workspace count follows effective Settings preview");
