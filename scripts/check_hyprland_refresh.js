#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const base = path.join(__dirname, '..', 'Titonium', 'Services', 'Hyprland');
const source = fs.readFileSync(path.join(base, 'HyprlandService.qml'), 'utf8');
function rules(name) {
    const context = vm.createContext({});
    const file = path.join(base, name + '.js');
    if (fs.existsSync(file)) vm.runInContext(fs.readFileSync(file, 'utf8').replace(/^\.pragma library\s*\n/, ''), context);
    return context;
}
const windowRules = rules('WindowRules'), workspaceRules = rules('WorkspaceRules');
const eventRules = rules('WindowEventRules');
function fixture() {
    const pending = [];
    let resolutions = 0;
    const workspace = { id: 1, monitor: { name: 'DP-1' }, toplevels: { values: [] } };
    const monitor = { name: 'DP-1', focused: true, activeWorkspace: workspace };
    const windows = ['0xa', '0xb'].map((address, index) => ({ address, title: 'Title ' + index,
        urgent: false, workspace, lastIpcObject: { class: 'editor', initialClass: 'editor' },
        wayland: { appId: 'editor', title: 'Wayland ' + index, minimized: false } }));
    workspace.toplevels.values = windows;
    const hyprland = { toplevels: { values: windows }, workspaces: { values: [workspace] },
        monitors: { values: [monitor] }, activeToplevel: windows[0], focusedWorkspace: workspace,
        monitorFor: () => monitor };
    const root = { projectedWindows: [], recentWindowIds: [], focusedMonitorName: 'DP-1',
        focusInitialized: true, focusedWorkspaceIdValue: 1, windowRefreshQueued: false };
    Object.defineProperty(root, 'activeToplevelId', {get: () => hyprland.activeToplevel?.address || ''});
    Object.defineProperty(root, 'windows', {get: () => root.projectedWindows});
    const context = vm.createContext({ root, Hyprland: hyprland, WindowRules: windowRules,
        WorkspaceRules: workspaceRules, WindowEventRules: eventRules,
        WindowRegistry: { replace() {} }, ScreenPolicy: { screens: [{ name: 'DP-1' }] },
        ApplicationService: { descriptorForWindowIdentity(identity) {
            resolutions++; return { appId: identity.appId || identity.ipcClass, icon: 'editor', fallbackIcon: 'apps' };
        } }, Qt: { callLater: fn => pending.push(fn) } });
    function compile(name) {
        const match = new RegExp('function ' + name + '\\(([^)]*)\\): \\w+ \\{').exec(source);
        assert.ok(match, 'native refresh handler exists: ' + name);
        let depth = 1, cursor = match.index + match[0].length;
        const start = cursor;
        while (depth && cursor < source.length) {
            const char = source[cursor++];
            if (char === '{') depth++; else if (char === '}') depth--;
        }
        return vm.runInContext(`(function(${match[1].replace(/:\s*\w+/g, '')}) {${source.slice(start, cursor - 1)}})`, context);
    }
    for (const match of source.matchAll(/^    function (\w+)\(/gm)) root[match[1]] = compile(match[1]);
    root.recomputeWindows();
    resolutions = 0;
    return { root, hyprland, windows, workspace, monitor,
        raw(name, fields = []) { compile('onRawEvent')({ name, parse: () => fields }); },
        signal(name) { compile(name)(); },
        flush() { while (pending.length) pending.shift()(); },
        resolutionCount: () => resolutions,
    };
}
let failures = 0;
function test(name, run) {
    try { run(); console.log('PASS ' + name); }
    catch (error) { failures++; console.error('FAIL ' + name + ': ' + error.message); }
}
test('unrelated keyboard/layer/capture events do not resolve window identities', () => {
    const f = fixture(), original = f.root.projectedWindows;
    for (const event of ['activelayout', 'openlayer', 'closelayer', 'submap', 'screencast', 'screencastv2', 'bell'])
        f.raw(event);
    f.flush();
    assert.equal(f.resolutionCount(), 0);
    assert.equal(f.root.projectedWindows, original);
});
test('raw and native focus burst projects latest focus once and preserves MRU', () => {
    const f = fixture();
    f.hyprland.activeToplevel = f.windows[1];
    f.raw('activewindow'); f.raw('activewindowv2');
    f.signal('onActiveToplevelChanged'); f.signal('onFocusedWorkspaceChanged');
    f.flush();
    assert.equal(f.resolutionCount(), 2, 'one two-window identity pass per event-loop burst');
    assert.deepEqual(Array.from(f.root.projectedWindows, window => [window.id, window.active]), [['0xb', true], ['0xa', false]]);
});
test('title urgent minimize and workspace signals publish latest window facts', () => {
    const f = fixture();
    f.windows[0].title = 'Updated title'; f.windows[0].urgent = true; f.windows[0].wayland.minimized = true;
    f.windows[0].workspace = { id: 2, monitor: { name: 'DP-1' } };
    for (const signal of ['onTitleChanged', 'onUrgentChanged', 'onMinimizedChanged', 'onWorkspaceChanged']) f.signal(signal);
    f.flush();
    assert.equal(f.resolutionCount(), 2);
    const first = f.root.projectedWindows.find(window => window.id === '0xa');
    assert.deepEqual([first.title, first.urgent, first.minimized, first.workspaceId], ['Updated title', true, true, 2]);
    assert.equal(f.root.workspaceWindowCount, 1, 'Dock emptiness counts only policy-screen workspace');
});
test('raw focused monitor payload stays immediate while descriptor refresh waits', () => {
    const f = fixture();
    f.raw('focusedmonv2', ['DP-3', '8']);
    assert.equal(f.root.focusedMonitorName, 'DP-3');
    assert.equal(f.root.focusedWorkspaceIdValue, 8);
    assert.equal(f.resolutionCount(), 0);
    f.flush();
    assert.equal(f.root.focusedWorkspaceIdValue, 8, 'stale monitor snapshot cannot overwrite event-backed focus');
});
test('late native replies and new/removed windows are not lost after a flush', () => {
    const f = fixture();
    f.raw('windowtitlev2'); f.flush();
    f.windows[0].title = 'Late IPC title';
    f.signal('onLastIpcObjectChanged'); f.flush();
    assert.equal(f.root.projectedWindows[0].title, 'Late IPC title');
    f.hyprland.toplevels.values = [f.windows[1]];
    f.signal('onValuesChanged'); f.flush();
    assert.deepEqual(Array.from(f.root.projectedWindows, window => window.id), ['0xb']);
    f.hyprland.toplevels.values.push({ ...f.windows[0], address: '0xc' });
    f.signal('onValuesChanged'); f.flush();
    assert.deepEqual(Array.from(f.root.projectedWindows, window => window.id), ['0xb', '0xc']);
});
test('monitor workspace and catalog changes refresh descriptor consumers', () => {
    const f = fixture();
    f.monitor.activeWorkspace = { id: 3 };
    f.signal('onActiveWorkspaceChanged');
    f.windows[0].wayland.appId = 'new-editor';
    f.signal('onAppIdChanged'); f.signal('onAllApplicationsChanged');
    f.flush();
    assert.equal(f.root.workspaceWindowCount, 0);
    assert.equal(f.root.projectedWindows[0].appId, 'new-editor');
    assert.equal(f.resolutionCount(), 2);
});
test('unknown compositor events retain conservative refresh fallback', () => {
    const f = fixture();
    f.raw('future-window-change'); f.flush();
    assert.equal(f.resolutionCount(), 2);
});
process.exitCode = failures ? 1 : 0;
