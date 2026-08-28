#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const helperPath = path.join(__dirname, "..", "Titonium", "Theme", "WorkspaceColors.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL shared workspace color rules are missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({ Math, Number, Array });
vm.runInContext(source, context, { filename: helperPath });

const palette = ["blue", "green", "amber", "purple", "red", "cyan", "indigo", "brown"];
assert.equal(context.workspaceColor(1, palette, "idle"), "blue");
assert.equal(context.workspaceColor(8, palette, "idle"), "brown");
assert.equal(context.workspaceColor(9, palette, "idle"), "blue");
assert.equal(context.workspaceColor(0, palette, "idle"), "idle");
assert.equal(context.tileColor(3, false, false, palette, "idle"), "idle");
assert.equal(context.tileColor(3, true, false, palette, "idle"), "amber");
assert.equal(context.tileColor(4, false, true, palette, "idle"), "purple");

console.log("PASS shared workspace interaction color cycling");
