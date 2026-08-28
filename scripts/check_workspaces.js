#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const helperPath = path.join(root, "Titonium", "Services", "Hyprland", "WorkspaceRules.js");
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

assert.equal(context.groupStart(1, 5), 1);
assert.equal(context.groupStart(5, 5), 1);
assert.equal(context.groupStart(6, 5), 6);
assert.equal(context.groupStart(-1, 5), 1);

const six = context.project(6, 6, [], []);
assert.deepEqual(plain(six.map(item => item.id)), [1, 2, 3, 4, 5, 6]);
assert.deepEqual(plain(six.map(item => item.colorIndex)), [0, 1, 2, 3, 4, 5]);

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
    apps: [{ appId: "Code", icon: "editor" }], colorIndex: 5,
    rangeStart: 6, rangeEnd: 7,
});
assert.deepEqual(plain(projected[1]), {
    id: 7, active: true, occupied: true, urgent: false,
    apps: [
        { appId: "Firefox", icon: "firefox" },
        { appId: "kitty", icon: "terminal" },
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
assert.deepEqual(plain(projected[4].apps), [{ appId: "Notes", icon: "notes" }]);
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
assert.equal(visual.pillHeight(true), 28);
assert.equal(visual.slotHeight(), 28);
assert.equal(visual.backgroundColor(0, false, mutedPalette, activeBlue), "#233a5e");
assert.equal(visual.backgroundColor(3, false, mutedPalette, activeBlue), "#49305f");
assert.equal(visual.backgroundColor(3, true, mutedPalette, activeBlue), activeBlue);
assert.equal(visual.backgroundColor(8, true, mutedPalette, activeBlue), activeBlue);

console.log("PASS workspace projection, muted palette, active-blue highlight and roomy pill fixtures");
