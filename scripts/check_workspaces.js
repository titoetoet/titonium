#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const helperPath = path.join(root, "Titonium", "Services", "Hyprland", "WorkspaceRules.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL Workspace rules are missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({ Math, Number, Object, Array, isFinite });
vm.runInContext(source, context, { filename: helperPath });
const plain = value => JSON.parse(JSON.stringify(value));

assert.equal(context.groupStart(1, 5), 1);
assert.equal(context.groupStart(5, 5), 1);
assert.equal(context.groupStart(6, 5), 6);
assert.equal(context.groupStart(-1, 5), 1);

const projected = context.project(7, 5, [
    { id: 6, occupied: true, urgent: false },
    { id: 7, occupied: true, urgent: false },
    { id: 9, occupied: true, urgent: true },
], [
    { id: "recent", workspaceId: 7, icon: "firefox", appId: "Firefox", native: { secret: true } },
    { id: "older", workspaceId: 7, icon: "terminal", appId: "kitty" },
    { id: "other", workspaceId: 9, icon: "monitor", appId: "btop" },
]);

assert.deepEqual(plain(projected.map(item => item.id)), [6, 7, 8, 9, 10]);
assert.deepEqual(plain(projected[0]), {
    id: 6, active: false, occupied: true, urgent: false,
    icon: "", appId: "", rangeStart: 6, rangeEnd: 7,
});
assert.deepEqual(plain(projected[1]), {
    id: 7, active: true, occupied: true, urgent: false,
    icon: "firefox", appId: "Firefox", rangeStart: 6, rangeEnd: 7,
});
assert.deepEqual(plain(projected[2]), {
    id: 8, active: false, occupied: false, urgent: false,
    icon: "", appId: "", rangeStart: 0, rangeEnd: 0,
});
assert.equal(projected[3].rangeStart, 9);
assert.equal(projected[3].rangeEnd, 9);
assert.equal(projected[3].urgent, true);
assert.equal(Object.isFrozen(projected), true);
assert.equal(projected.every(Object.isFrozen), true);
assert.equal(JSON.stringify(projected).includes("native"), false);
assert.equal(JSON.stringify(projected).includes("toplevel"), false);
assert.equal(JSON.stringify(projected).includes("workspace\""), false);

console.log("PASS five-slot workspace grouping, ranges, MRU icon, and raw-object rejection fixtures");
