#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const helperPath = path.join(__dirname, "..", "Titonium", "Services", "Audio", "AudioRules.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL Audio rules are missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({});
vm.runInContext(source, context, { filename: helperPath });
const rules = context;

assert.equal(rules.maximumOutput(false), 1.0);
assert.equal(rules.maximumOutput(true), 1.5);
assert.equal(rules.clampOutput(1.3, false), 1.0);
assert.equal(rules.clampOutput(1.3, true), 1.3);
assert.equal(rules.clampOutput(Number.NaN, true), null);
assert.equal(rules.clampUnit(-0.5), 0.0);
assert.equal(rules.clampUnit(1.2), 1.0);
assert.equal(rules.adjustOutput(0.98, 0.05, false), 1.0);
assert.equal(rules.adjustOutput(1.0, 0.05, true), 1.05);
assert.equal(rules.adjustOutput("bad", 0.05, true), null);

assert.equal(rules.volumeIcon(false, false, 0.5), "volume_off");
assert.equal(rules.volumeIcon(true, true, 0.5), "volume_off");
assert.equal(rules.volumeIcon(true, false, 0.0), "volume_mute");
assert.equal(rules.volumeIcon(true, false, 0.2), "volume_down");
assert.equal(rules.volumeIcon(true, false, 0.6), "volume_up");

const playback = { id: 7, audio: { volume: 0.4, muted: false },
    isStream: true, isSink: false,
    properties: { "application.name": "Firefox", "application.icon-name": "firefox" } };
assert.equal(rules.isPlaybackStream(playback), true);
assert.equal(rules.isPlaybackStream({ audio: {}, isStream: true, isSink: true }), false);
assert.equal(rules.streamName(playback, "Audio stream"), "Firefox");
assert.equal(rules.streamIcon(playback), "firefox");
assert.equal(rules.streamName({ properties: { "media.name": "Track" } }, "Audio stream"), "Track");
assert.equal(rules.streamIcon({ properties: {} }), "audio-x-generic");

const streams = rules.normalizedStreams([
    { id: 20, audio: { volume: 0.3, muted: false }, isStream: true, isSink: false,
        properties: { "application.name": "zeta" } },
    { id: 3, audio: { volume: 0.5, muted: true }, isStream: true, isSink: false,
        properties: { "application.name": "Alpha" } },
    { id: 4, audio: { volume: 0.5, muted: false }, isStream: true, isSink: false,
        properties: { "application.name": "alpha" } },
    { id: 8, audio: { volume: 0.5, muted: false }, isStream: true, isSink: false,
        isHardware: true, properties: { "application.name": "Hardware" } },
    { id: 9, audio: { volume: 0.5, muted: false }, isStream: true, isSink: false,
        isRecording: true, properties: { "application.name": "Recorder" } },
]);
assert.deepEqual(streams.map(stream => stream.name), ["Alpha", "alpha", "zeta"]);
assert.deepEqual(streams.map(stream => stream.id), [3, 4, 20]);
assert.deepEqual(Object.keys(streams[0]).sort(), ["available", "icon", "id", "muted", "name", "volume"]);
assert.equal(streams[0].available, true);
assert.notStrictEqual(streams[0], streams[1]);

assert.equal(rules.presentationEvent(null,
    { key: "sink:1", available: true, volume: 0.5, muted: false }).emit, false);
assert.equal(rules.presentationEvent(
    { key: "sink:1", available: true, volume: 0.5, muted: false },
    { key: "sink:1", available: true, volume: 0.6, muted: false }).emit, true);
assert.equal(rules.presentationEvent(
    { key: "sink:1", available: true, volume: 0.6, muted: false },
    { key: "sink:2", available: true, volume: 0.6, muted: false }).emit, false);
assert.equal(rules.presentationEvent(
    { key: "sink:1", available: true, volume: 0.6, muted: false },
    { key: "", available: false, volume: 0, muted: false }).emit, false);
assert.equal(rules.presentationEvent(
    { key: "", available: true, volume: 0.5, muted: false },
    { key: "", available: true, volume: 0.6, muted: false }).emit, false);

console.log("PASS Audio rules fixtures");
