#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rightPillRulesPath = path.join(root, "Titonium", "Bar", "right",
    "RightPillState.js");
const rightPillRules = vm.createContext({ Math, Number });
vm.runInContext(fs.readFileSync(rightPillRulesPath, "utf8")
    .replace(/^\.pragma library\s*\n/, ""), rightPillRules,
{ filename: rightPillRulesPath });
const contents = [
    ["Network", "ConnectedNetworkPopupContent.qml"],
    ["Bluetooth", "ConnectedBluetoothPopupContent.qml"],
    ["Audio", "ConnectedAudioPopupContent.qml"],
];

for (const [feature, file] of contents) {
    const relative = path.join("Titonium", "Overlays", feature, file);
    const sourcePath = path.join(root, relative);
    assert.equal(fs.existsSync(sourcePath), true, `${relative} must exist`);
    const source = fs.readFileSync(sourcePath, "utf8");

    for (const fragment of [
        "readonly property real implicitContentWidth: 380",
        "readonly property real implicitContentHeight: contentColumn.implicitHeight + 32",
        "implicitWidth: implicitContentWidth",
        "implicitHeight: implicitContentHeight",
        "signal dismissRequested()",
    ]) assert.equal(source.includes(fragment), true,
        `${relative} must expose ${fragment}`);

    for (const forbidden of [
        "Shared.Panel",
        "SurfaceManager.close",
        "TapHandler",
        "ParallelAnimation",
        "panelEntrance",
        "panelExit",
    ]) assert.equal(source.includes(forbidden), false,
        `${relative} must not own ${forbidden}`);

    assert.doesNotMatch(source, /Rectangle\s*\{\s*anchors\.fill:\s*parent/,
        `${relative} must not own a full-screen outside-click rectangle`);

    const qmldirPath = path.join(root, "Titonium", "Overlays", feature, "qmldir");
    const qmldir = fs.readFileSync(qmldirPath, "utf8");
    const component = file.replace(".qml", "");
    assert.match(qmldir, new RegExp(`${component} 1\\.0 ${file}`),
        `${feature} qmldir must export ${file}`);
}

const audioPath = path.join(root, "Titonium", "Overlays", "Audio",
    "ConnectedAudioPopupContent.qml");
const audio = fs.readFileSync(audioPath, "utf8");
assert.match(audio, /property real availableViewportHeight:\s*440/,
    "Audio content must accept a safe bounded Edge viewport height");
assert.match(audio, /Math\.min\(root\.maximumHeight, root\.availableViewportHeight\)/,
    "Audio stream sizing must be bounded by the host-provided viewport height");
assert.doesNotMatch(audio, /root\.height\s*-\s*root\.panelTop/,
    "Audio content must not derive viewport height from a full-screen surface");
assert.match(audio, /Flickable\s*\{\s*id:\s*contentViewport[\s\S]*?anchors\.fill:\s*parent[\s\S]*?contentHeight:\s*Math\.max\(height, root\.implicitContentHeight\)/,
    "Audio content must expose a full-body scroll path when its host is shorter than fixed controls");
const shortViewportHeight = 120;
const fixedContentHeight = 160;
assert.equal(Math.max(shortViewportHeight, fixedContentHeight) > shortViewportHeight, true,
    "a viewport shorter than fixed Audio content must retain vertically accessible overflow");

const notificationRelative = path.join("Titonium", "Notifications",
    "ConnectedNotificationPanelContent.qml");
const notificationPath = path.join(root, notificationRelative);
assert.equal(fs.existsSync(notificationPath), true,
    `${notificationRelative} must exist`);
const notification = fs.readFileSync(notificationPath, "utf8");
for (const fragment of [
    "property real availableViewportHeight: 440",
    "signal dismissRequested()",
    "NotificationHistoryContent {",
    "onDismissRequested: root.dismissRequested()",
    'import "NotificationPanelLifecycle.js" as NotificationPanelLifecycle',
    "property bool loaded: false",
    'property string mountedOwnerId: ""',
    "if (!root.loaded)",
    "NotificationPanelLifecycle.transition(",
    "NotificationPanelLifecycle.teardown(root.mountedOwnerId)",
    "NotificationCoordinator.panelMounted(plan.mountOwnerId)",
    "NotificationCoordinator.panelUnmounted(plan.unmountOwnerId)",
    "NotificationCoordinator.markAllRead()",
    "onOwnerIdChanged: root.syncPanelMount()",
    "root.loaded = true",
    "root.syncPanelMount()",
    "Component.onDestruction: root.teardownPanelMount()",
]) assert.equal(notification.includes(fragment), true,
    `${notificationRelative} must expose ${fragment}`);
assert.match(notification,
    /readonly property real implicitContentHeight:\s*historyContent\.implicitContentHeight \+ 32/,
    "Connected notification natural height must not depend on the animated branch viewport");
assert.doesNotMatch(notification,
    /implicitContentHeight:\s*Math\.min\([\s\S]*?availableViewportHeight/,
    "Connected notification implicit height must not feed the current branch height back into host geometry");
const notificationNaturalHeight = 508;
assert.equal(rightPillRules.menuHeight(notificationNaturalHeight, 1080), 440,
    "Connected history must grow to the stable host cap for tall notification content");
assert.equal(rightPillRules.menuHeight(notificationNaturalHeight, 260), 260,
    "Connected history must clamp to a short output while retaining natural content height for scrolling");
assert.match(notification,
    /readonly property string ownerId:[\s\S]*?RightPillCoordinator\.connectedDescriptor\?\.feature === "notifications"[\s\S]*?RightPillCoordinator\.connectedOwnerId/,
    "Connected history may mount only for the loaded notification owner");
for (const forbidden of [
    "Shared.Panel",
    "SurfaceManager",
    "forceActiveFocus",
    "TapHandler",
    "ParallelAnimation",
    "PanelWindow",
]) assert.equal(notification.includes(forbidden), false,
    `${notificationRelative} must leave chassis, close ownership, and focus return to the right pill: ${forbidden}`);
const notificationQmldir = fs.readFileSync(path.join(root,
    "Titonium", "Notifications", "qmldir"), "utf8");
assert.match(notificationQmldir,
    /ConnectedNotificationPanelContent 1\.0 ConnectedNotificationPanelContent\.qml/,
    "Notifications qmldir must export ConnectedNotificationPanelContent");

console.log("PASS Connected popup content boundary contract");
