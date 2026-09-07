#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const base = path.join(__dirname, '..', 'Titonium', 'Services', 'Dock');
const rules = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(base, 'DockRules.js'), 'utf8').replace(/^\.pragma library\s*\n/, ''), rules);
const qml = fs.readFileSync(path.join(base, 'DockService.qml'), 'utf8');
// Execute the service's real function bodies; only native side effects are replaced.
const functions = [...qml.matchAll(/^    function (\w+)\(([^\n]*)\): \w+ \{\n([\s\S]*?)^    \}/gm)];
function fixture(alias = 'org.example.Editor') {
    const entry = { id: 'org.example.Editor', name: 'Editor', icon: 'editor' };
    const focused = [], launched = [], closed = [];
    const root = { firstSeenIds: [], cyclesByAppId: {}, mutationWarningCounts: {} };
    const hyprland = {
        windows: ['A', 'B', 'C'].map((id, index) => ({ id, appId: alias, active: index === 0,
            urgent: false, workspaceId: 1, title: id, icon: '', fallbackIcon: 'apps', minimized: false, monitorName: 'DP-1' })),
        activeWorkspaceWindowCount: 3,
        focusWindow(id) { focused.push(id); this.activate(id); return true; },
        activate(id) {
            this.windows = this.windows.map(window => ({ ...window, active: window.id === id }));
            this.windows.sort((a, b) => Number(b.active) - Number(a.active));
            root.recompute();
        },
        closeWindow(id) { closed.push(id); return true; },
    };
    const application = {
        allApplications: [entry],
        desktopEntryForAppId: id => ['editor-alias', entry.id.toLowerCase()].includes(id.toLowerCase()) ? entry : null,
        nameForAppId: id => id, iconForAppId: () => 'editor',
        launch: id => { launched.push(id); return true; },
    };
    const context = vm.createContext({ root, HyprlandService: hyprland, ApplicationService: application,
        DockRules: rules, DockStore: { pinnedIds: [] }, Preferences: { hiddenApplicationIds: [] }, Logger: { warn() {} } });
    for (const [, name, args, body] of functions) {
        const parameters = args.replace(/:\s*\w+/g, '');
        root[name] = vm.runInContext(`(function(${parameters}) {${body}\n})`, context);
    }
    root.recompute();
    return { root, hyprland, focused, launched, closed };
}
const selected = process.argv[2];
if (!selected || selected === 'identity') {
    const f = fixture('editor-alias');
    assert.equal(f.root.projectedItems[0].appId, 'org.example.Editor');
    assert.equal(f.root.projectedItems[0].runningCount, 3);
    assert.equal(f.root.activateOrLaunch(f.root.projectedItems[0].appId), true);
    assert.deepEqual(f.launched, [], 'activating a canonical Dock item must not launch an aliased running app');
    assert.deepEqual(f.focused, ['A']);
    f.hyprland.activate('B');
    assert.equal(f.root.closeActive('org.example.Editor'), true);
    assert.deepEqual(f.closed, ['B'], 'close resolves the same canonical app identity as projection');
    assert.equal(f.root.windowsForAppId('editor-alias').length, 3);
    const aliases = fixture('editor-alias');
    aliases.root.activateOrLaunch('org.example.Editor');
    aliases.root.activateOrLaunch('editor-alias');
    assert.deepEqual(aliases.focused, ['A', 'B'], 'alias and desktop ID share one cycle');
    const unknown = fixture('uninstalled-app');
    unknown.root.activateOrLaunch('uninstalled-app');
    unknown.root.closeActive('uninstalled-app');
    assert.deepEqual(unknown.focused, ['A'], 'uncatalogued running apps retain their source identity');
    assert.deepEqual(unknown.closed, ['A']);
    console.log('PASS Dock canonical identity action fixtures');
}
if (!selected || selected === 'cycle') {
    const f = fixture();
    for (let i = 0; i < 7; i++) f.root.activateOrLaunch('org.example.Editor');
    assert.deepEqual(f.focused, ['A', 'B', 'C', 'A', 'B', 'C', 'A'], 'MRU updates must not reorder the Dock cycle');
    f.hyprland.activate('C');
    f.root.activateOrLaunch('org.example.Editor');
    f.root.activateOrLaunch('org.example.Editor');
    assert.deepEqual(f.focused.slice(-2), ['C', 'A'], 'external focus rebases the cycle on the active window');
    f.hyprland.windows = f.hyprland.windows.filter(window => window.id !== 'A');
    f.hyprland.activate('B');
    f.root.activateOrLaunch('org.example.Editor');
    f.root.activateOrLaunch('org.example.Editor');
    assert.deepEqual(f.focused.slice(-2), ['B', 'C'], 'removing the previous window keeps the surviving cycle');
    f.hyprland.windows = [];
    f.root.recompute();
    f.hyprland.windows = [{ id: 'D', appId: 'org.example.Editor', active: true }];
    f.root.recompute();
    f.root.activateOrLaunch('org.example.Editor');
    assert.equal(f.focused.at(-1), 'D', 'reopened apps cannot retain stale window IDs');
    const delayed = fixture();
    delayed.hyprland.focusWindow = id => { delayed.focused.push(id); return true; };
    for (let i = 0; i < 4; i++) delayed.root.activateOrLaunch('org.example.Editor');
    assert.deepEqual(delayed.focused, ['A', 'B', 'C', 'A'], 'pending compositor focus cannot rewind the cycle');
    delayed.root.recompute(); // An unrelated update still reports the original active A.
    delayed.hyprland.activate('B');
    delayed.hyprland.activate('C');
    delayed.hyprland.activate('A');
    delayed.root.activateOrLaunch('org.example.Editor');
    assert.equal(delayed.focused.at(-1), 'B', 'late focus acknowledgements preserve the accepted cycle position');
    delayed.hyprland.activate('B');
    delayed.hyprland.activate('C');
    delayed.root.activateOrLaunch('org.example.Editor');
    assert.equal(delayed.focused.at(-1), 'C', 'observed external focus still rebases after delayed dispatch');
    const added = fixture();
    added.root.activateOrLaunch('org.example.Editor');
    added.hyprland.windows.push({ id: 'D', appId: 'org.example.Editor', active: false });
    for (let i = 0; i < 4; i++) added.root.activateOrLaunch('org.example.Editor');
    assert.deepEqual(added.focused, ['A', 'B', 'C', 'D', 'A'], 'new windows append without disrupting the ring');
    const rejected = fixture();
    rejected.root.activateOrLaunch('org.example.Editor');
    const originalFocus = rejected.hyprland.focusWindow;
    rejected.hyprland.focusWindow = () => false;
    assert.equal(rejected.root.activateOrLaunch('org.example.Editor'), false);
    rejected.hyprland.focusWindow = originalFocus;
    rejected.root.activateOrLaunch('org.example.Editor');
    assert.deepEqual(rejected.focused, ['A', 'B'], 'rejected focus must not advance the cycle');
    rejected.hyprland.activate('outside-app');
    rejected.root.activateOrLaunch('org.example.Editor');
    assert.equal(rejected.focused.at(-1), 'B', 'returning from another app focuses the most recent window');
    console.log('PASS Dock stable window cycle fixtures');
}
