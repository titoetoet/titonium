#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const projectRoot = path.join(__dirname, "..");
const historyPath = path.join(projectRoot, "Titonium", "Foundation", "ClipboardHistory.js");

function fail(label, detail) {
    console.error(`FAIL clipboard history ${label}: ${detail}`);
    process.exit(1);
}

function assertEqual(actual, expected, label) {
    if (actual !== expected)
        fail(label, `expected ${JSON.stringify(expected)}, received ${JSON.stringify(actual)}`);
}

function assertDeepEqual(actual, expected, label) {
    const received = JSON.stringify(actual);
    const wanted = JSON.stringify(expected);
    if (received !== wanted)
        fail(label, `expected ${wanted}, received ${received}`);
}

if (!fs.existsSync(historyPath))
    fail("module", "Foundation/ClipboardHistory.js is missing");

const context = { JSON, Math, Date };
vm.createContext(context);
const source = fs.readFileSync(historyPath, "utf8").replace(/^\.pragma library\s*/, "");
vm.runInContext(source, context, { filename: historyPath });

const valid = JSON.parse(fs.readFileSync(path.join(projectRoot, "tests", "fixtures", "clipboard-history.valid.json"), "utf8"));
const invalid = JSON.parse(fs.readFileSync(path.join(projectRoot, "tests", "fixtures", "clipboard-history.invalid.json"), "utf8"));

assertDeepEqual(Array.from(context.normalizeDocument(invalid)), [], "malformed document falls back to empty history");
const normalized = Array.from(context.normalizeDocument(valid));
assertEqual(normalized.length, 2, "well-typed records are retained and invalid records are dropped");
assertDeepEqual(Array.from(normalized, item => item.id), ["valid-url", "valid-plain"], "valid record order is retained");

const protoFirst = context.createRecord("__proto__", 2000);
const protoSecond = { ...context.createRecord("__proto__", 1000), id: "older-proto" };
const normalizedProto = Array.from(context.normalizeDocument({
    schemaVersion: 1,
    items: [protoFirst, protoSecond],
}));
assertEqual(normalizedProto.length, 1, "exact __proto__ text dedupes safely");
assertEqual(normalizedProto[0].id, protoFirst.id, "__proto__ dedupe retains the newest record");

const moved = Array.from(context.record(normalized, "https://example.com", 3000));
assertEqual(moved.length, 2, "exact duplicate remains unique");
assertEqual(moved[0].id, "valid-url", "exact duplicate moves existing record to front");
assertEqual(moved[0].timestamp, 3000, "exact duplicate refreshes timestamp");

let capped = [];
for (let index = 1; index <= 61; index++)
    capped = context.record(capped, `record ${index}`, 1000 + index);
assertEqual(capped.length, 60, "history is capped at sixty records");
assertEqual(capped[0].text, "record 61", "newest record is first");
assertEqual(capped[59].text, "record 2", "sixty-first insertion drops oldest record");

assertDeepEqual(context.classify("https://example.com/path?q=1"), { kind: "url", colorHex: "" }, "URL classification");
assertDeepEqual(context.classify("#3a7"), { kind: "color", colorHex: "#3a7" }, "short color classification");
assertDeepEqual(context.classify("#33AA77CC"), { kind: "color", colorHex: "#33AA77CC" }, "alpha color classification");
assertDeepEqual(context.classify("function greet(name) {\n  return name;\n}"), { kind: "code", colorHex: "" }, "code classification");
assertDeepEqual(context.classify("A quiet plain sentence."), { kind: "plain", colorHex: "" }, "plain classification");

assertEqual(context.preview("first line\nsecond\tline"), "first line second line", "preview is single-line");
assertEqual(context.preview("x".repeat(80)), "x".repeat(80), "preview retains exactly eighty characters");
assertEqual(context.preview("x".repeat(81)), "x".repeat(79) + "…", "preview truncates after the exact eighty-character boundary");

console.log("PASS clipboard history fixtures (20)");
