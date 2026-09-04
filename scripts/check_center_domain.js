#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const rulesPath = path.join(__dirname, "..", "Titonium", "Services", "Center",
    "CenterDomainRules.js");
if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing Titonium/Services/Center/CenterDomainRules.js");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

const notificationRulesPath = path.join(path.dirname(rulesPath), "adapters",
    "NotificationCenterRules.js");
assert.equal(fs.existsSync(notificationRulesPath), true,
    "Notification Center projection rules must normalize coordinator values");
const notificationRules = vm.createContext({ encodeURIComponent, decodeURIComponent });
vm.runInContext(fs.readFileSync(notificationRulesPath, "utf8")
    .replace(/^\.pragma library\s*\n/, ""), notificationRules,
{ filename: notificationRulesPath });

function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

function context(id, sourceName, kind, title, occurredAt, overrides = {}) {
    return Object.assign({
        id,
        source: sourceName,
        kind,
        title,
        subtitle: "",
        icon: "bolt",
        tone: "normal",
        attention: "ambient",
        progress: null,
        occurredAt,
        expiresAt: 0,
        details: {},
        actionIds: [],
    }, overrides);
}

const criticalDescriptor = Object.freeze({
    key: "native:7",
    source: "native",
    appName: "Fixture Mail",
    appIcon: "mail-unread",
    summary: "Reply needed",
    body: "Please review the draft",
    severity: "critical",
    category: "notification",
    actions: Object.freeze([Object.freeze({ id: "open.reply", label: "Open" })]),
    receivedAt: 700,
});
const criticalContext = notificationRules.context(criticalDescriptor);
assert.deepEqual(plain(criticalContext), {
    id: "notification:native:7",
    source: "notification",
    kind: "notification",
    title: "Reply needed",
    subtitle: "Please review the draft",
    icon: "mail-unread",
    tone: "critical",
    attention: "transient",
    progress: null,
    occurredAt: 700,
    expiresAt: 0,
    details: {
        notificationKey: "native:7",
        appName: "Fixture Mail",
        body: "Please review the draft",
        category: "notification",
    },
    actionIds: ["notification.action:open.reply", "notification.dismiss"],
});
assert.equal(Object.isFrozen(criticalContext), true);
assert.equal(Object.isFrozen(criticalContext.details), true);
assert.equal(Object.isFrozen(criticalContext.actionIds), true);
assert.deepEqual(plain(notificationRules.capabilities(criticalDescriptor, criticalContext.id)), [{
    id: "notification.action:open.reply",
    contextId: "notification:native:7",
    role: "primary",
    label: "Open",
    icon: "open_in_new",
    enabled: true,
}, {
    id: "notification.dismiss",
    contextId: "notification:native:7",
    role: "destructive",
    label: "Dismiss",
    icon: "close",
    enabled: true,
}]);
assert.deepEqual(plain(notificationRules.presentation(criticalDescriptor)), {
    id: "notification:native:7:presentation",
    source: "notification",
    contextId: "notification:native:7",
    requestedMode: "banner",
    attention: "transient",
    timeoutMs: 4000,
    focusPolicy: "none",
});
assert.deepEqual(plain(notificationRules.actionIntent(
    "notification.action:open.reply", "notification:native:7")), {
    kind: "action", key: "native:7", actionId: "open.reply",
});
assert.deepEqual(plain(notificationRules.actionIntent(
    "notification.dismiss", "notification:native:7")), {
    kind: "dismiss", key: "native:7", actionId: "",
});
console.log("PASS coordinator critical values normalize into one Center presentation context");

const allSources = ["capture", "media", "notification", "agent", "focus", "timer", "job"];
const sourceContexts = allSources.map((name, index) =>
    context(`${name}:one`, name, `${name}-kind`, `${name} title`, 10 + index));
const normalizedSources = sourceContexts.map(item => rules.normalizeContext(item, 100));
assert.deepEqual(normalizedSources.map(item => item.source), allSources);
assert.ok(normalizedSources.every(item => Object.isFrozen(item)
    && Object.isFrozen(item.details) && Object.isFrozen(item.actionIds)));
console.log("PASS Center Domain normalizes all seven sources into frozen contexts");

const raw = {
    contexts: [
        context("focus:daily", "focus", "daily", "Ship Center", 10,
            { icon: "center_focus_strong" }),
        context("media:vlc", "media", "playback", "Track", 20, {
            subtitle: "Artist",
            icon: "music_note",
            progress: 0.5,
            details: { identity: "VLC" },
            actionIds: ["media.toggle"],
        }),
    ],
    indicators: [],
    actions: [{
        id: "media.toggle",
        contextId: "media:vlc",
        role: "primary",
        label: "Pause",
        icon: "pause",
        enabled: true,
    }],
};

const first = rules.snapshot(null, raw, 100);
assert.equal(first.revision, 1);
assert.equal(first.primary.id, "focus:daily");
assert.equal(first.secondary.id, "media:vlc");
assert.ok(Object.isFrozen(first));
assert.ok(Object.isFrozen(first.contexts));
assert.ok(Object.isFrozen(first.contexts[1].details));
assert.ok(Object.isFrozen(first.capabilities));
assert.ok(Object.isFrozen(first.capabilities.actions));
assert.strictEqual(rules.snapshot(first, raw, 101), first);
const second = rules.snapshot(first, Object.assign({}, raw, {
    indicators: [{ id: "recording", icon: "screen_record",
        accessibleName: "Recording", tone: "critical", active: true }],
}), 102);
assert.equal(second.revision, 2);
assert.equal(second.indicators[0].id, "recording");
console.log("PASS semantic snapshots are recursively frozen and revision-stable");

const staleCapability = rules.normalizeCapability({
    id: "job.clear", contextId: "job:missing", role: "secondary",
    label: "Clear", icon: "close", enabled: true,
}, ["focus:daily"]);
assert.equal(staleCapability, null);
assert.equal(rules.normalizeContext(Object.assign({}, raw.contexts[0], { callback() {} }), 100), null);
assert.equal(rules.normalizeIndicator({ id: "bad", icon: "warning",
    accessibleName: "Bad", tone: "urgent", active: true }), null);
console.log("PASS malformed and cross-snapshot values fail closed");

assert.deepEqual(plain(rules.actionResult({ accepted: true, status: "completed",
    reason: "", closePolicy: "compact", leaked: "value" })), {
    accepted: true,
    status: "completed",
    reason: "",
    closePolicy: "compact",
});
assert.deepEqual(plain(rules.actionResult({ accepted: true, status: "unknown" })), {
    accepted: false,
    status: "rejected",
    reason: "invalid-result",
    closePolicy: "keep",
});
console.log("PASS Center Domain normalizes action results");

const centerRoot = path.dirname(rulesPath);
const adapterNames = ["Capture", "Media", "Notification", "AgentApproval",
    "Focus", "Timer", "Job"];
for (const name of adapterNames) {
    const adapterPath = path.join(centerRoot, "adapters", `${name}CenterAdapter.qml`);
    assert.equal(fs.existsSync(adapterPath), true, `missing ${name} Center adapter`);
    const adapterSource = fs.readFileSync(adapterPath, "utf8");
    for (const fragment of ["readonly property var contexts", "readonly property var indicators",
        "readonly property var actions", "function dispatch(actionId: string, contextId: string,"])
        assert.match(adapterSource, new RegExp(fragment.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
    assert.doesNotMatch(adapterSource, /\b(Process|FileView|Timer)\s*\{/);
}

const notificationAdapter = fs.readFileSync(path.join(centerRoot, "adapters",
    "NotificationCenterAdapter.qml"), "utf8");
for (const fragment of [
    "NotificationCoordinator.currentCritical",
    "NotificationCenterRules.context(root.currentCritical)",
    "NotificationCenterRules.capabilities(root.currentCritical, root.context.id)",
    "NotificationCenterRules.presentation(root.currentCritical)",
    "function setPresentationEligible(eligible: bool): bool",
    "function pausePresentation(contextId: string): bool",
    "function resumePresentation(contextId: string): bool",
    "function completePresentation(contextId: string): var",
    "NotificationCoordinator.setCriticalPresentationEligible(eligible)",
    "NotificationCoordinator.pauseCritical()",
    "NotificationCoordinator.resumeCritical()",
    "NotificationCoordinator.completeCritical(intent.key)",
])
    assert.ok(notificationAdapter.includes(fragment),
        `Notification adapter missing coordinator contract: ${fragment}`);
assert.doesNotMatch(notificationAdapter, /\bNotificationService\b|\+ item\.id|notificationId: item\.id/,
    "Notification adapter must consume only coordinator-resolved values");
assert.match(notificationAdapter,
    /function setPresentationEligible\(eligible: bool\): bool \{[\s\S]*?if \(!eligible\)[\s\S]*?NotificationCoordinator\.pauseCritical\(\)[\s\S]*?NotificationCoordinator\.setCriticalPresentationEligible\(eligible\)[\s\S]*?if \(eligible\)[\s\S]*?NotificationCoordinator\.resumeCritical\(\)/,
    "ineligible user interaction must suspend, then resume, the coordinator deadline");
console.log("PASS Notification Center adapter preserves coordinator authority and stable keys");

for (const file of ["CenterDomain.qml", "CenterActionDispatcher.qml"])
    assert.equal(fs.existsSync(path.join(centerRoot, file)), true, `missing ${file}`);
assert.match(fs.readFileSync(path.join(centerRoot, "qmldir"), "utf8"),
    /CenterActionDispatcher 1\.0 CenterActionDispatcher\.qml/,
    "CenterActionDispatcher must be exported for runtime construction");
const domainSource = fs.readFileSync(path.join(centerRoot, "CenterDomain.qml"), "utf8");
assert.match(domainSource, /readonly property var snapshot/);
assert.match(domainSource, /signal presentationRequested\(var request\)/);
assert.match(domainSource, /signal presentationEnded\(var request\)/);
assert.match(domainSource, /function dispatch\(intent: var\): var/);
for (const fragment of [
    "function setPresentationEligible(eligible: bool): bool",
    "function pausePresentation(contextId: string): bool",
    "function resumePresentation(contextId: string): bool",
    "function completePresentation(contextId: string): var",
    "root.notifications.presentation",
])
    assert.ok(domainSource.includes(fragment), `Center Domain missing ${fragment}`);
assert.match(domainSource,
    /const previousPresentationId = String\([\s\n]*root\.notifications\.presentation\?\.id \|\| ""\);[\s\S]*?const resumedPresentationId = String\([\s\n]*root\.notifications\.presentation\?\.id \|\| ""\);[\s\S]*?root\.syncNotificationPresentation\([\s\n]*previousPresentationId === resumedPresentationId\)/,
    "first eligibility must emit once while a resumed paused item is re-presented");
console.log("PASS Center Domain owns seven narrow listener-free adapters and dispatch boundary");
