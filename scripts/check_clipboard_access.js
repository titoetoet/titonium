#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const accessPath = path.join(
    __dirname,
    "..",
    "Titonium/Platform/Clipboard/ClipboardAccess.js",
);

if (!fs.existsSync(accessPath)) {
    console.error("FAIL Clipboard access helper is missing");
    process.exit(1);
}

const context = vm.createContext({ String });
const source = fs.readFileSync(accessPath, "utf8").replace(/^\.pragma library\s*/, "");
vm.runInContext(source, context, { filename: accessPath });

function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

assert.deepEqual(plain(context.observe(() => "seed text")), {
    available: true,
    error: "",
    detail: "",
    text: "seed text",
}, "an injected Clipboard read reports available text");

const unavailableRead = context.observe(() => { throw new Error("fake read denial"); });
assert.equal(unavailableRead.available, false, "a thrown Clipboard read marks the adapter unavailable");
assert.equal(unavailableRead.error, "clipboard.error.unavailable", "read failure exposes a stable error");
assert.match(unavailableRead.detail, /fake read denial/, "read failure retains diagnostic detail");

let copied = "";
assert.deepEqual(plain(context.copy("copied text", text => { copied = text; })), {
    accepted: true,
    available: true,
    error: "",
    detail: "",
}, "an injected Clipboard write reports accepted availability");
assert.equal(copied, "copied text", "the injected writer receives exact Clipboard text");

const unavailableWrite = context.copy("blocked", () => { throw new Error("fake write denial"); });
assert.equal(unavailableWrite.accepted, false, "a thrown Clipboard write is rejected");
assert.equal(unavailableWrite.available, false, "a thrown Clipboard write marks the adapter unavailable");
assert.equal(unavailableWrite.error, "clipboard.error.unavailable", "write failure exposes a stable error");

console.log("PASS Clipboard access injection fakes (10)");
