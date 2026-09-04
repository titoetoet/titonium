#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Shared", "IconRules.js");

assert.equal(fs.existsSync(rulesPath), true,
    "IconRules must exist so filesystem icon sources cannot leak into glyph text");

const source = fs.readFileSync(rulesPath, "utf8")
    .replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

assert.equal(rules.semanticName("deployed_code", "image"), "deployed_code");
assert.equal(rules.semanticName("  smart_toy  ", "image"), "smart_toy");
assert.equal(rules.semanticName(
    "/home/cole/.local/share/icons/hicolor/scalable/apps/discord.svg", "apps"),
    "apps", "an absolute SVG path must render the semantic fallback, not path text");
assert.equal(rules.semanticName(
    "file:///home/cole/.local/share/icons/hicolor/scalable/apps/discord.svg", "apps"),
    "apps", "a file URL must render the semantic fallback, not URL text");
assert.equal(rules.semanticName("qrc:/icons/discord.svg", "apps"), "apps");

console.log("PASS semantic icon names reject image-source paths");
