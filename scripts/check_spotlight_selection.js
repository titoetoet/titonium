#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname,
    "../Titonium/Overlays/Spotlight/SpotlightModel.qml"), "utf8");
const calls = [];
const root = { mode: "results", results: [], selectedIndex: 0, selectionMoved: false };
const context = vm.createContext({ root,
    ApplicationService: { launch: id => { calls.push(["launch", id]); return true; } },
    ClipboardService: { copyText: text => { calls.push(["copy", text]); return true; } },
});
// Execute production methods; replace only native launch/clipboard boundaries.
for (const match of source.matchAll(/^    function (\w+)\(([^\n]*)\): \w+ \{\n([\s\S]*?)^    \}/gm)) {
    const args = match[2].replace(/: \w+/g, "");
    root[match[1]] = vm.runInContext(`(function(${args}) {\n${match[3]}\n})`, context);
}
function updateResults(results) {
    root.results = results;
    const handler = source.match(/^    onResultsChanged: (.+)$/m);
    if (handler)
        vm.runInContext(handler[1], context);
}
const app = id => ({ id, type: "application", executionId: id });

updateResults([app("a"), app("b"), app("c")]);
root.selectResult(2);
updateResults([app("a")]);
assert.equal(root.selectedIndex, 0, "catalog shrink keeps the visible selection in range");
assert.equal(root.activateSelected(), true);
assert.deepEqual(calls.pop(), ["launch", "a"]);

updateResults([]);
assert.equal(root.activateSelected(), false, "empty catalog never launches");
assert.equal(calls.length, 0);
updateResults([app("b")]);
assert.equal(root.activateSelected(), true, "results repopulate with a usable selection");
assert.deepEqual(calls.pop(), ["launch", "b"]);

root.selectedIndex = 5;
assert.equal(root.activateSelected(), false, "stale activation never dereferences a missing row");
assert.equal(calls.length, 0);
root.selectionMoved = false;
assert.equal(root.activateSelected(), true, "unmoved selection retains first-result activation");
assert.deepEqual(calls.pop(), ["launch", "b"]);

root.mode = "clipboard";
root.selectedIndex = -1;
updateResults([]);
assert.equal(root.selectedIndex, -1, "application updates preserve Clipboard's no-selection state");
root.mode = "results";
root.selectionMoved = true;
updateResults([{ id: "calculator:4", type: "calculator", value: "4" }]);
assert.equal(root.activateSelected(), true);
assert.deepEqual(calls.pop(), ["copy", "4"]);
console.log("PASS Spotlight catalog-change selection and guarded activation");
