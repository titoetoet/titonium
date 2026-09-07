#!/usr/bin/env node
// Execute timer/coordinator/bridge methods with pure rules and an isolated clock.
// No QML construction, live timer, compositor, clipboard or native notification calls.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const base = path.join(__dirname, '..', 'Titonium');
const read = relative => fs.readFileSync(path.join(base, relative), 'utf8');
function rules(relative) {
    const context = vm.createContext({});
    vm.runInContext(read(relative).replace(/^\.pragma library\s*\n/, ''), context);
    return context;
}
function methods(source, root, dependencies) {
    const context = vm.createContext({root, ...dependencies});
    for (const match of source.matchAll(/^    function (\w+)\(([^)]*)\): \w+ \{\n([\s\S]*?)^    \}/gm)) {
        const args = match[2].replace(/:\s*\w+/g, '');
        root[match[1]] = vm.runInContext(`(function(${args}) {${match[3]}\n})`, context);
    }
}
const timerRules = rules('Services/Center/CenterTimerRules.js');
const notificationRules = rules('Services/Notifications/NotificationRules.js');
const coordinatorRules = rules('Services/Notifications/NotificationCoordinatorRules.js');
function fixture() {
    let now = 100000;
    const clock = { now: () => now };
    const coordinator = { coordinatorState: coordinatorRules.initialState(),
        appliedPreferences: {}, appliedNotificationPreferences: {} };
    methods(read('Services/Notifications/NotificationCoordinator.qml'), coordinator,
        { Date: clock, NotificationRules: notificationRules, CoordinatorRules: coordinatorRules });
    const bridge = read('Orchestration/NotificationBridge.qml').split('property Connections timerNotifications: Connections {')[1];
    const signalContext = vm.createContext({ NotificationCoordinator: coordinator });
    const timer = { timerState: timerRules.initialState(), scheduledAt: 0,
        milestoneTimer: { stop() {}, start() {}, interval: 0 } };
    for (const match of bridge.matchAll(/function on(Notification\w+)\(([^)]*)\): void \{\n([\s\S]*?)\n        \}/g)) {
        const name = match[1][0].toLowerCase() + match[1].slice(1);
        timer[name] = vm.runInContext(`(function(${match[2].replace(/:\s*\w+/g, '')}) {${match[3]}})`, signalContext);
    }
    const attention = new Set(), activities = new Set();
    methods(read('Services/Center/CenterTimerService.qml'), timer, {
        Date: clock, CenterTimerRules: timerRules, I18n: { tr: key => key },
        CenterAttentionService: { clear: key => attention.delete(key), acknowledge: key => attention.delete(key),
            publish: event => attention.add(event.id), setIndicator() {} },
        CenterActivityService: { upsert: activity => activities.add(activity.id), remove: id => activities.delete(id) },
    });
    return { timer, coordinator, attention, activities,
        finish(id) { assert.equal(timer.start(id, 1, id), true); now += 1000; timer.processDue(); },
        pending() { return Array.from(coordinator.coordinatorState.criticalQueue, item => item.key); },
        history() { return Array.from(coordinator.coordinatorState.history, item => item.key); },
        unread() { return Array.from(coordinator.coordinatorState.unreadKeys); },
    };
}
const key = id => 'internal:timer_finished:' + id;
let failures = 0;
function test(name, run) {
    try { run(); console.log('PASS ' + name); }
    catch (error) { failures++; console.error('FAIL ' + name + ': ' + error.message); }
}
test('valid restart retires only the old current completion and preserves history/unread', () => {
    const f = fixture(); f.finish('tea'); f.finish('tea:other');
    const history = f.history(), unread = f.unread();
    assert.equal(f.coordinator.coordinatorState.currentCritical.key, key('tea'));
    assert.equal(f.timer.start(' tea ', 60, 'Fresh tea'), true);
    assert.deepEqual(f.pending(), [key('tea:other')]);
    assert.equal(f.coordinator.coordinatorState.currentCritical.key, key('tea:other'));
    assert.deepEqual(f.history(), history); assert.deepEqual(f.unread(), unread);
    assert.equal(f.activities.has('timer:tea'), true);
});
test('cancel retires a queued completion without dismissing current or history', () => {
    const f = fixture(); f.finish('first'); f.finish('second');
    const history = f.history(), unread = f.unread();
    f.timer.cancel(' second ');
    assert.deepEqual(f.pending(), [key('first')]);
    assert.equal(f.coordinator.coordinatorState.currentCritical.key, key('first'));
    assert.deepEqual(f.history(), history); assert.deepEqual(f.unread(), unread);
    f.timer.cancel('first');
    assert.equal(f.coordinator.coordinatorState.currentCritical, null);
    assert.deepEqual(f.history(), history);
});
test('invalid restart and unknown cancel preserve unrelated completion state', () => {
    const f = fixture(); f.finish('tea');
    const state = f.coordinator.coordinatorState;
    assert.equal(f.timer.start('tea', 0, 'Tea'), false);
    assert.equal(f.timer.start('tea', 2, ''), false);
    assert.equal(f.timer.start('', 2, 'Tea'), false);
    assert.equal(f.timer.cancel(''), false);
    assert.equal(f.timer.cancel('unknown'), false);
    assert.equal(f.coordinator.coordinatorState, state);
});
test('active cancellation retains existing return and milestone cleanup semantics', () => {
    const f = fixture();
    assert.equal(f.timer.start('tea', 600, 'Tea'), true);
    f.attention.add('timer:tea'); f.attention.add('timer:other');
    assert.equal(f.timer.cancel('tea'), true);
    assert.equal(f.timer.timerState.length, 0);
    assert.equal(f.activities.has('timer:tea'), false);
    assert.deepEqual([...f.attention], ['timer:other']);
});
process.exitCode = failures ? 1 : 0;
