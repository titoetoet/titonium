#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
function load(file) {
    const ctx = vm.createContext({});
    vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
    return ctx;
}
const failures = [];
function test(name, fn) { try { fn(); console.log('PASS ' + name); } catch (e) { failures.push(name); console.error('FAIL ' + name + ': ' + e.message); } }
const titles = load('Titonium/Bar/islands/ActiveWindowRules.js');
test('browser suffix is removed without losing tab context', () => {
    assert.equal(titles.presentation('Google Chrome', '', '(9) WhatsApp - Google Chrome', false).title, '(9) WhatsApp');
    assert.equal(titles.presentation('Firefox', '', 'MDN — Firefox', false).title, 'MDN');
    assert.equal(titles.presentation('Google Chrome', '', 'Google Chrome tips', false).title, 'Google Chrome tips');
});
const catalog = load('Titonium/Settings/SettingsCatalog.js');
test('reset page isolation and non-editable About', () => {
    assert.equal(typeof catalog.resetPaths, 'function');
    assert.deepEqual(Array.from(catalog.resetPaths('audio')), ['modules.audio']);
    assert.deepEqual(Array.from(catalog.resetPaths('general')), ['locale', 'accessibility']);
    assert.deepEqual(Array.from(catalog.resetPaths('spotlight')), ['modules.spotlight', 'applications']);
    assert.deepEqual(Array.from(catalog.resetPaths('about')), []);
    assert.deepEqual(Array.from(catalog.resetPaths('invalid')), []);
});
const notices = load('Titonium/Services/Notifications/NotificationRules.js');
test('groups preserve source, newest order, action identity and input', () => {
    assert.equal(typeof notices.historyGroups, 'function');
    const history = [
        {key:'1', source:'native', appId:'chrome', appName:'Chrome'},
        {key:'2', source:'native', appId:'other', appName:'Chrome'},
        {key:'3', source:'native', appId:'chrome', appName:'Chrome'},
        {key:'4', source:'internal', appId:'chrome', appName:'Chrome'}
    ];
    const groups = notices.historyGroups(history);
    assert.equal(groups.length, 3);
    assert.deepEqual(Array.from(groups[0].items, n => n.key), ['1','3']);
    assert.equal(groups[0].items[0], history[0]);
    assert.equal(history.length, 4);
    assert.equal(notices.historyGroups([]).length, 0);
});
const audio = load('Titonium/Overlays/Audio/AudioGeometry.js');
test('application viewport reserves whole rows independently from animated parent', () => {
    assert.equal(typeof audio.streamListHeight, 'function');
    assert.equal(audio.streamListHeight(0, 72, 8), 0);
    assert.equal(audio.streamListHeight(1, 72, 8), 72);
    assert.equal(audio.streamListHeight(6, 72, 8), 232);
});
if (failures.length) process.exit(1);
