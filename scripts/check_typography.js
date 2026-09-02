#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const projectRoot = path.join(__dirname, "..");
const scalePath = path.join(projectRoot, "Titonium", "Theme", "TypographyScale.js");
const typographyPath = path.join(projectRoot, "Titonium", "Theme", "Typography.qml");
const iconFontPath = path.join(projectRoot, "Titonium", "Theme", "assets",
    "MaterialSymbolsRounded.ttf");
const iconLicensePath = path.join(projectRoot, "Titonium", "Theme", "assets",
    "LICENSE.MaterialSymbols.txt");

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

if (!fs.existsSync(iconFontPath) || fs.statSync(iconFontPath).size < 1_000_000) {
    console.error("FAIL typography contract: bundled Material Symbols Rounded font is missing");
    process.exit(1);
}

if (!fs.existsSync(iconLicensePath)) {
    console.error("FAIL typography contract: Material Symbols license is missing");
    process.exit(1);
}

const typography = fs.readFileSync(typographyPath, "utf8");
if (!typography.includes("FontLoader")
        || !typography.includes('Qt.resolvedUrl("assets/MaterialSymbolsRounded.ttf")')
        || !typography.includes("materialSymbolsLoader.name")) {
    console.error("FAIL typography contract: Typography must load its bundled icon font");
    process.exit(1);
}

console.log("PASS typography scale and bundled icon font");
