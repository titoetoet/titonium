#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const sourcePath = path.join(__dirname, "..", "Titonium", "Modules", "MenuBar", "Launcher", "LauncherLayout.js");
if (!fs.existsSync(sourcePath)) {
    console.error("FAIL fixed launcher layout: LauncherLayout.js is missing");
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

assertEqual(context.columnCount(), 6, "fixed column count");
assertEqual(context.rowCount(), 4, "fixed row count");
assertEqual(context.pageSize(), 24, "fixed page capacity");
if (typeof context.indicatorWidth !== "function") {
    console.error("FAIL occupancy indicator: indicatorWidth is missing");
    process.exit(1);
}
assertDeepEqual(Array.from(context.pages(Array.from({ length: 25 }, (_, index) => index + 1), 24), page => Array.from(page).length), [24, 1], "fixed pagination");
assertEqual(context.fillRatio([25], 24), 1 / 24, "partial-page fill ratio");
assertEqual(context.indicatorWidth(Array.from({ length: 24 }), 24), 40, "full-page indicator width");
assertEqual(context.indicatorWidth(Array.from({ length: 6 }), 24), 16, "quarter-page indicator width");
assertDeepEqual(Array.from(context.pages([], 24), page => Array.from(page)), [[]], "empty catalog page");

console.log("PASS fixed 6x4 launcher layout fixtures (8)");
