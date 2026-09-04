#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Notifications", "NotificationRules.js");
const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });
const plain = value => JSON.parse(JSON.stringify(value));

const preferences = overrides => ({
    modules: {
        notifications: {
            policyMode: "custom",
            allowCriticalOnIsland: true,
            keepCriticalUnread: true,
            applicationOverrides: overrides || {},
        },
    },
});

const native = (urgency, appId = "org.example.Mail") => rules.descriptor({
    id: 7,
    appId,
    appName: "Mail",
    urgency,
    summary: "Build failed",
    body: "This text must never alter notification policy",
}, 1234);

assert.equal(rules.nativeUrgency(-1), "low");
assert.equal(rules.nativeUrgency(0), "low");
assert.equal(rules.nativeUrgency(1), "normal");
assert.equal(rules.nativeUrgency(2), "critical");
assert.equal(rules.nativeUrgency(99), "critical");
assert.equal(rules.nativeUrgency("critical"), "normal");

const normal = native(1);
assert.deepEqual(plain(normal), {
    key: "native:7",
    source: "native",
    appId: "org.example.Mail",
    appName: "Mail",
    appIcon: "",
    summary: "Build failed",
    body: "This text must never alter notification policy",
    urgency: 1,
    nativeUrgency: "normal",
    severity: "normal",
    route: "toast",
    category: "notification",
    actions: [],
    receivedAt: 1234,
});
assert.equal(Object.isFrozen(normal), true);
assert.equal(Object.isFrozen(normal.actions), true);

const actionsDescriptor = rules.descriptor({
    id: 8,
    appId: "org.example.Actions",
    actions: [{ id: " reply ", label: " Reply " }],
}, 1235);
assert.deepEqual(plain(actionsDescriptor.actions), [{ id: "reply", label: "Reply" }]);
assert.equal(Object.isFrozen(actionsDescriptor.actions), true);
assert.equal(Object.isFrozen(actionsDescriptor.actions[0]), true);

assert.deepEqual(plain(rules.resolvePolicy(native(0), preferences())), {
    ...plain(normal),
    urgency: 0,
    nativeUrgency: "low",
});
assert.deepEqual(plain(rules.resolvePolicy(native(2), preferences())), {
    ...plain(normal),
    urgency: 2,
    nativeUrgency: "critical",
    severity: "critical",
    route: "center",
});

for (const [kind, category] of [
    ["job_failed", "job"],
    ["job_requires_action", "job"],
    ["timer_finished", "timer"],
]) {
    const internal = rules.descriptor({
        key: `internal:${kind}:42`,
        source: "internal",
        kind,
        category,
        summary: "normal-looking text",
    }, 2000);
    assert.deepEqual(plain(rules.resolvePolicy(internal, preferences())), {
        key: `internal:${kind}:42`,
        source: "internal",
        appId: "",
        appName: "",
        appIcon: "",
        summary: "normal-looking text",
        body: "",
        urgency: 1,
        nativeUrgency: "normal",
        severity: "critical",
        route: "center",
        category,
        actions: [],
        receivedAt: 2000,
    });
}

const internalSingleSpace = rules.descriptor({
    key: "internal:job_failed:build 42",
    source: "internal",
    kind: "job_failed",
}, 2001);
const internalDoubleSpace = rules.descriptor({
    key: "internal:job_failed:build  42",
    source: "internal",
    kind: "job_failed",
}, 2002);
assert.equal(internalSingleSpace.key, "internal:job_failed:build 42");
assert.equal(internalDoubleSpace.key, "internal:job_failed:build  42");
assert.notEqual(internalSingleSpace.key, internalDoubleSpace.key,
    "internal Job/Timer IDs preserve internal whitespace for exact lifecycle identity");
assert.equal(rules.resolvePolicy(internalSingleSpace, preferences()).route, "center");
assert.equal(rules.resolvePolicy(internalDoubleSpace, preferences()).route, "center");

for (const [override, severity, route] of [
    ["follow", "critical", "center"],
    ["quiet", "normal", "history"],
    ["normal", "normal", "toast"],
    ["critical", "critical", "center"],
    ["block", "normal", "block"],
]) {
    const resolved = rules.resolvePolicy(native(2), preferences({
        "org.example.Mail": override,
    }));
    assert.equal(resolved.severity, severity, `${override} severity`);
    assert.equal(resolved.route, route, `${override} route`);
}

const automatic = rules.resolvePolicy(native(2), {
    modules: { notifications: { policyMode: "automatic", applicationOverrides: {
        "org.example.Mail": "quiet",
    } } },
});
assert.equal(automatic.route, "center", "automatic ignores application overrides");

const invalid = rules.resolvePolicy(native(1), {
    modules: { notifications: { policyMode: "unknown", applicationOverrides: {
        "org.example.Mail": "untrusted",
    } } },
});
assert.equal(invalid.severity, "normal");
assert.equal(invalid.route, "toast");

const inferred = rules.resolvePolicy(native(0), preferences());
assert.equal(inferred.severity, "normal", "title/body text never upgrades severity");
assert.equal(inferred.route, "toast", "title/body text never upgrades route");

const islandBlocked = rules.resolvePolicy(native(2), {
    modules: { notifications: { allowCriticalOnIsland: false } },
});
assert.equal(islandBlocked.route, "history");
const customIslandBlocked = rules.resolvePolicy(native(1), {
    modules: { notifications: {
        policyMode: "custom",
        allowCriticalOnIsland: false,
        applicationOverrides: { "org.example.Mail": "critical" },
    } },
});
assert.equal(customIslandBlocked.route, "history");

assert.equal(rules.historyLimit(), 100);
assert.equal(rules.toastLimit(), 3);
assert.equal(rules.criticalQueueLimit(), 16);
assert.equal(Object.isFrozen(rules.resolvePolicy(native(1), preferences())), true);
console.log("PASS notification policy urgency, safety mappings, overrides, caps and immutability");
