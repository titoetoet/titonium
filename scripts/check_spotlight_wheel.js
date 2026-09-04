#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const rulesPath = path.join(__dirname, "..", "Titonium", "Overlays", "Spotlight",
    "SpotlightWheelPaging.js");
const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({ Math, Number, Object });
vm.runInContext(source, rules, { filename: rulesPath });
const plain = value => JSON.parse(JSON.stringify(value));

let state = rules.update(-40, 1000, 0, 4, 0, 0);
assert.deepEqual(plain(state), { page: 0, consumed: false, accumulator: -40,
    lastConsumedAt: 0 });
state = rules.update(-50, 1020, 0, 4, state.lastConsumedAt, state.accumulator);
assert.deepEqual(plain(state), { page: 1, consumed: true, accumulator: 0,
    lastConsumedAt: 1020 });
state = rules.update(-120, 1040, 1, 4, state.lastConsumedAt, state.accumulator);
assert.equal(state.page, 1, "one wheel burst must not skip across pages");
state = rules.update(-120, 1250, 1, 4, state.lastConsumedAt, state.accumulator);
assert.equal(state.page, 2, "a later wheel gesture advances one more page");
assert.equal(rules.update(120, 1500, 0, 4, 0, 0).page, 0, "paging is bounded at start");
assert.equal(rules.update(-120, 1500, 3, 4, 0, 0).page, 3, "paging is bounded at end");

console.log("PASS Spotlight wheel gesture paging");
