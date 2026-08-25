#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const sourcePath = path.join(__dirname, "..", "Titonium", "Modules", "MenuBar", "Launcher", "LauncherLayout.js");
if (!fs.existsSync(sourcePath)) {
    console.error("FAIL adaptive launcher layout: LauncherLayout.js is missing");
    process.exit(1);
}
const context = { Math };
vm.createContext(context);
const source = fs.readFileSync(sourcePath, "utf8").replace(/^\.pragma library\s*/, "");
vm.runInContext(source, context, { filename: sourcePath });

function assertEqual(actual, expected, label) {
    if (actual !== expected) {
        console.error(`FAIL ${label}: expected ${expected}, received ${actual}`);
        process.exit(1);
    }
}

function assertDeepEqual(actual, expected, label) {
    const received = JSON.stringify(actual);
    const wanted = JSON.stringify(expected);
    if (received !== wanted) {
        console.error(`FAIL ${label}: expected ${wanted}, received ${received}`);
        process.exit(1);
    }
}

assertEqual(context.columnCount(840, 120, 8), 6, "wide column count");
assertEqual(context.columnCount(612, 120, 8), 4, "constrained column count");
assertEqual(context.rowCount(500, 112, 8), 4, "row count");
assertDeepEqual(Array.from(context.pages([1, 2, 3, 4, 5], 4), page => Array.from(page)), [[1, 2, 3, 4], [5]], "pagination");
assertEqual(context.fillRatio([5], 4), 0.25, "partial-page fill ratio");
assertDeepEqual(Array.from(context.pages([], 4), page => Array.from(page)), [[]], "empty catalog page");

console.log("PASS adaptive launcher layout fixtures (6)");
