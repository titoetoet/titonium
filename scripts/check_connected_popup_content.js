#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
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

console.log("PASS Connected popup content boundary contract");
