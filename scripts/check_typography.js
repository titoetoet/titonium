#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const projectRoot = path.join(__dirname, "..");
const scalePath = path.join(projectRoot, "Titonium", "Theme", "TypographyScale.js");

if (!fs.existsSync(scalePath)) {
    console.error("FAIL typography contract: TypographyScale.js is missing");
    process.exit(1);
}

const context = { Math };
vm.createContext(context);
vm.runInContext(fs.readFileSync(scalePath, "utf8").replace(/^\.pragma library\s*/, ""), context,
    { filename: scalePath });

function assertEqual(actual, expected, label) {
    if (actual !== expected) {
        console.error(`FAIL ${label}: expected ${expected}, received ${actual}`);
        process.exit(1);
    }
}

const expectedSizes = {
    micro: 11,
    caption: 12,
    bodySmall: 13,
    body: 14,
    bodyLarge: 15,
    label: 14,
    titleSmall: 16,
    title: 17,
    titleLarge: 20,
    display: 28,
    mono: 14
};

for (const [variant, expected] of Object.entries(expectedSizes))
    assertEqual(context.sizeFor(variant), expected, `${variant} resolves to the readable shell size`);

assertEqual(context.sizeFor("unknown"), 14, "unknown typography variants fall back to body");

console.log("PASS typography scale");
