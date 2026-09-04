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
