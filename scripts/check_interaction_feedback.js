const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const context = vm.createContext({});
const file = path.join(__dirname, '../Titonium/Shared/InteractionState.js');
assert.ok(fs.existsSync(file), 'shared interaction state must exist');
vm.runInContext(fs.readFileSync(file, 'utf8'), context);
const state = (...args) => JSON.parse(JSON.stringify(context.feedback(...args)));
assert.deepEqual(state(true, false, false, false, false, false),
    { hover: 0, press: 0, active: false, warning: false, focus: false });
assert.equal(state(true, true, false, false, false, false).hover, 1);
assert.equal(state(true, true, true, false, false, false).hover, 0,
    'press replaces hover light with tactile fill');
assert.equal(state(true, true, true, false, false, false).press, 1);
const combined = state(true, true, true, true, true, true);
assert.equal(combined.active, true, 'press cannot erase active status');
assert.equal(combined.warning, true, 'press cannot erase warning');
assert.equal(combined.focus, true, 'pointer feedback cannot erase keyboard focus');
assert.deepEqual(state(false, true, true, true, true, true),
    { hover: 0, press: 0, active: false, warning: false, focus: false });
console.log('PASS interaction state: idle, hover, press, active, warning, focus, disabled');
