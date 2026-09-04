#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Notifications", "NotificationRules.js");

if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing Titonium/Services/Notifications/NotificationRules.js");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });
const plain = value => JSON.parse(JSON.stringify(value));

const descriptor = rules.descriptor({
    id: 7,
    appName: " Mail ",
    appIcon: " mail-client ",
    summary: " Hello ",
    body: "one\ntwo\tthree",
    urgency: 1,
    native: { secret: true },
}, 1234);
assert.deepEqual(plain(descriptor), {
    key: "native:7",
    source: "native",
    appId: "Mail",
    appName: "Mail",
    appIcon: "mail-client",
    summary: "Hello",
    body: "one two three",
    urgency: 1,
    nativeUrgency: "normal",
    severity: "normal",
    route: "toast",
    category: "notification",
    actions: [],
    receivedAt: 1234,
});
assert.deepEqual(Object.keys(descriptor), [
    "key", "source", "appId", "appName", "appIcon", "summary", "body",
    "urgency", "nativeUrgency", "severity", "route", "category", "actions", "receivedAt",
]);
assert.equal(Object.isFrozen(descriptor), true);
assert.equal(Object.isFrozen(descriptor.actions), true);
assert.equal(rules.descriptor({ id: 0 }, 1), null);
assert.equal(rules.descriptor({ id: -1 }, 1), null);
assert.equal(rules.descriptor({ id: "7" }, 1), null);

const history = Array.from({ length: 100 }, (_, index) => Object.freeze({ key: `native:${index + 1}` }));
const replacement = Object.freeze({ key: "native:50", summary: "new" });
const replaced = rules.upsert(history, replacement, 100);
assert.equal(replaced.length, 100);
assert.equal(replaced[0], replacement);
assert.equal(replaced.filter(item => item.key === "native:50").length, 1);
assert.equal(replaced.some(item => item.key === "native:100"), true);
assert.equal(Object.isFrozen(replaced), true);
const inserted = rules.upsert(history, Object.freeze({ key: "native:101" }), 100);
assert.equal(inserted.length, 100);
assert.equal(inserted.some(item => item.key === "native:100"), false);

const replacementState = rules.refreshState({
    notifications: [Object.freeze({ key: "native:7", summary: "Unchanged" }),
        Object.freeze({ key: "native:8", summary: "Earlier" })],
    unreadKeys: ["native:7"],
    toastKeys: ["native:8", "native:7"],
}, Object.freeze({ key: "native:8", summary: "Replacement", route: "center" }), true);
assert.deepEqual(plain(replacementState), {
    notifications: [
        { key: "native:8", summary: "Replacement", route: "center" },
        { key: "native:7", summary: "Unchanged" },
    ],
    unreadKeys: ["native:8", "native:7"],
    toastKeys: ["native:7"],
});
assert.ok(Object.isFrozen(replacementState));
assert.ok(Object.isFrozen(replacementState.notifications));

const dismissedState = rules.dismissState({
    notifications: [{ key: "native:8" }, { key: "native:7" }],
    unreadKeys: ["native:8", "native:7"],
    toastKeys: ["native:8"],
}, "native:8");
assert.deepEqual(plain(dismissedState), {
    notifications: [{ key: "native:7" }],
    unreadKeys: ["native:7"],
    toastKeys: [],
});
assert.deepEqual(plain(rules.clearState({
    notifications: [{ key: "native:8" }], unreadKeys: ["native:8"], toastKeys: ["native:8"],
})), { notifications: [], unreadKeys: [], toastKeys: [] });

let warningCounts = Object.freeze({});
for (let attempt = 0; attempt < 3; attempt++) {
    const next = rules.warningState(warningCounts, "dismiss.stale", 3);
    assert.equal(next.warn, true);
    warningCounts = next.counts;
}
const cappedWarning = rules.warningState(warningCounts, "dismiss.stale", 3);
assert.equal(cappedWarning.warn, false);
assert.equal(cappedWarning.counts["dismiss.stale"], 3);
console.log("PASS notification replacement, stale cleanup, clear-all and warning-cap state fixtures");

assert.deepEqual(plain(rules.addToast(["native:3", "native:2", "native:1"], "native:4", 3)),
    ["native:4", "native:3", "native:2"]);
assert.deepEqual(plain(rules.addToast(["native:4", "native:3", "native:2"], "native:3", 3)),
    ["native:3", "native:4", "native:2"]);
assert.deepEqual(plain(rules.markUnread(["native:7"], "native:7")), ["native:7"]);
assert.deepEqual(plain(rules.markUnread(["native:7"], "native:8")), ["native:8", "native:7"]);
assert.equal(rules.unreadCount(["native:8", "native:7"]), 2);
assert.equal(rules.unreadCount(null), 0);
assert.deepEqual(plain(rules.removeKey(["native:8", "native:7", "native:8"], "native:8")),
    ["native:7"]);
assert.deepEqual(plain(rules.removeKey(["native:8", "native:7"], "")), ["native:8", "native:7"]);
assert.deepEqual(plain(rules.removeKey(["native:8", "native:7"], "native:7").slice(0, 0)), []);

const bulkRemoved = rules.removeKeys(
    [{ key: "native:9" }, { key: "native:8" }, { key: "native:7" }],
    ["native:8", "native:7", "native:7", ""]);
assert.deepEqual(plain(bulkRemoved), [{ key: "native:9" }]);
assert.deepEqual(plain(rules.removeKeys(["native:9", "native:8", "native:7"],
    ["native:9", "native:7"])), ["native:8"]);
assert.deepEqual(plain(rules.removeKeys(["native:9", "native:8"], [])), ["native:9", "native:8"]);
assert.equal(Object.isFrozen(rules.removeKeys(["native:9"], ["native:9"])), true);
console.log("PASS notification bulk removal preserves survivors and immutability");

const actionDescriptor = rules.descriptor({
    id: 9,
    actions: [
        { identifier: "open", text: "Open" },
        { id: "archive", label: "Archive" },
        { identifier: "  opaque\t action  ", text: "Opaque" },
        { identifier: "", text: "Ignored" },
    ],
}, 1300);
assert.deepEqual(plain(actionDescriptor.actions), [
    { id: "open", label: "Open" },
    { id: "archive", label: "Archive" },
    { id: "  opaque\t action  ", label: "Opaque" },
]);
assert.equal(Object.isFrozen(actionDescriptor.actions[0]), true);
assert.equal(rules.actionIdentifier({ identifier: "  opaque\t action  " }),
    "  opaque\t action  ");
assert.deepEqual(plain(rules.nativeActions({ actions: [
    { identifier: "open", text: "Open" },
] })), [{ id: "open", label: "Open" }]);
console.log("PASS notification descriptors project standard native actions without native objects");

const relativeNow = 200000000;
assert.deepEqual(plain(rules.relativeAge(relativeNow - 30000, relativeNow)), {
    unit: "now", count: 0,
});
assert.deepEqual(plain(rules.relativeAge(relativeNow - 300000, relativeNow)), {
    unit: "minutes", count: 5,
});
assert.deepEqual(plain(rules.relativeAge(relativeNow - 7200000, relativeNow)), {
    unit: "hours", count: 2,
});
assert.deepEqual(plain(rules.relativeAge(relativeNow - 172800000, relativeNow)), {
    unit: "days", count: 2,
});
assert.equal(rules.relativeAge(relativeNow + 1, relativeNow), null);
assert.equal(Object.isFrozen(
    rules.relativeAge(relativeNow - 30000, relativeNow)), true);
console.log("PASS notification relative age uses stable minute, hour and day buckets");
console.log("PASS notification descriptor, history, toast and unread rules fixtures");

assert.deepEqual(plain(rules.unreadIndicator(2,
    "Bạn có tin nhắn chưa đọc")), {
    id: "notification",
    icon: "mark_email_unread",
    accessibleName: "Bạn có tin nhắn chưa đọc",
    active: true,
});
assert.deepEqual(plain(rules.unreadIndicator(0,
    "Bạn có tin nhắn chưa đọc")), {
    id: "notification",
    icon: "mark_email_unread",
    accessibleName: "Bạn có tin nhắn chưa đọc",
    active: false,
});
console.log("PASS passive unread indicator");
