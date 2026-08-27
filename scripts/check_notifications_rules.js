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
    id: 7,
    appName: "Mail",
    appIcon: "mail-client",
    summary: "Hello",
    body: "one two three",
    urgency: 1,
    receivedAt: 1234,
});
assert.deepEqual(Object.keys(descriptor), [
    "id", "appName", "appIcon", "summary", "body", "urgency", "receivedAt",
]);
assert.equal(Object.isFrozen(descriptor), true);
assert.equal(rules.descriptor({ id: 0 }, 1), null);
assert.equal(rules.descriptor({ id: -1 }, 1), null);
assert.equal(rules.descriptor({ id: "7" }, 1), null);

const history = Array.from({ length: 100 }, (_, index) => Object.freeze({ id: index + 1 }));
const replacement = Object.freeze({ id: 50, summary: "new" });
const replaced = rules.upsert(history, replacement, 100);
assert.equal(replaced.length, 100);
assert.equal(replaced[0], replacement);
assert.equal(replaced.filter(item => item.id === 50).length, 1);
assert.equal(replaced.some(item => item.id === 100), true);
assert.equal(Object.isFrozen(replaced), true);
const inserted = rules.upsert(history, Object.freeze({ id: 101 }), 100);
assert.equal(inserted.length, 100);
assert.equal(inserted.some(item => item.id === 100), false);

assert.deepEqual(plain(rules.addToast([3, 2, 1], 4, 3)), [4, 3, 2]);
assert.deepEqual(plain(rules.addToast([4, 3, 2], 3, 3)), [3, 4, 2]);
assert.deepEqual(plain(rules.markUnread([7], 7)), [7]);
assert.deepEqual(plain(rules.markUnread([7], 8)), [8, 7]);
assert.equal(rules.unreadCount([8, 7]), 2);
assert.equal(rules.unreadCount(null), 0);
assert.deepEqual(plain(rules.removeId([8, 7, 8], 8)), [7]);
assert.deepEqual(plain(rules.removeId([8, 7], 0)), [8, 7]);
assert.deepEqual(plain(rules.removeId([8, 7], 7).slice(0, 0)), []);
console.log("PASS notification descriptor, history, toast and unread rules fixtures");
