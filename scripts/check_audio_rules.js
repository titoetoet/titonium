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

const playback = { id: 7, audio: { volume: 0.4, muted: false }, ready: true,
    isStream: true, isSink: true,
    properties: { "media.class": "Stream/Output/Audio",
        "application.name": "Firefox", "application.icon-name": "firefox" } };
assert.equal(rules.isPlaybackStream(playback), true);
assert.equal(rules.isPlaybackStream({ audio: {}, isStream: true, isSink: false,
    properties: { "media.class": "Stream/Input/Audio" } }), false);
assert.equal(rules.streamName(playback, "Audio stream"), "Firefox");
assert.equal(rules.streamIcon(playback), "firefox");
assert.equal(rules.streamName({ properties: { "media.name": "Track" } }, "Audio stream"), "Track");
assert.equal(rules.streamIcon({ properties: {} }), "audio-x-generic");

const streamNodes = [
    { id: 20, audio: { volume: 0.3, muted: false }, ready: true,
        isStream: true, isSink: true,
        properties: { "media.class": "Stream/Output/Audio", "application.name": "zeta" } },
    { id: 3, audio: { volume: 0.5, muted: true }, ready: true,
        isStream: true, isSink: true,
        properties: { "media.class": "Stream/Output/Audio", "application.name": "Alpha" } },
    { id: 4, audio: { volume: 0.5, muted: false }, ready: false,
        isStream: true, isSink: true,
        properties: { "media.class": "Stream/Output/Audio", "application.name": "alpha" } },
    { id: 8, audio: { volume: 0.5, muted: false }, ready: true,
        isStream: false, isSink: true, properties: { "application.name": "Hardware" } },
    { id: 9, audio: { volume: 0.5, muted: false }, ready: true,
        isStream: true, isSink: true, properties: { "application.name": "Recorder" } },
];
const streams = rules.normalizedStreams(streamNodes, "Audio stream", true);
assert.deepEqual(streams.map(stream => stream.name), ["Alpha", "alpha", "zeta"]);
assert.deepEqual(streams.map(stream => stream.id), [3, 4, 20]);
assert.deepEqual(Object.keys(streams[0]).sort(), ["available", "icon", "id", "muted", "name", "volume"]);
assert.equal(streams[0].available, true);
assert.equal(streams[1].available, false);
assert.notStrictEqual(streams[0], streams[1]);
assert.equal(rules.normalizedStreams(streamNodes, "Audio stream", false).length, 0);

const outputNodes = [
    { id: 41, audio: { volume: 0.6, muted: false }, ready: true,
        isStream: false, isSink: true, description: "HDMI / DisplayPort",
        properties: { "device.icon-name": "video-display" } },
    { id: 12, audio: { volume: 0.4, muted: false }, ready: true,
        isStream: false, isSink: true, nickname: "Analog Stereo", properties: {} },
    { id: 9, audio: { volume: 0.4, muted: false }, ready: false,
        isStream: false, isSink: true, description: "Unavailable", properties: {} },
    { id: 7, audio: { volume: 0.4, muted: false }, ready: true,
        isStream: true, isSink: true, description: "Capture stream", properties: {} },
];
const outputs = rules.normalizedOutputDevices(outputNodes, 41, "Output");
assert.deepEqual(outputs.map(device => device.id), [41, 12]);
assert.deepEqual(outputs.map(device => device.name), ["HDMI / DisplayPort", "Analog Stereo"]);
assert.deepEqual(outputs.map(device => device.icon), ["video-display", "volume_up"]);
assert.deepEqual(outputs.map(device => device.selected), [true, false]);
assert.deepEqual(Object.keys(outputs[0]).sort(), ["icon", "id", "name", "selected"]);
assert.equal(rules.normalizedOutputDevices(outputNodes, 999, "Output").length, 2);
assert.equal(rules.isOutputDevice(outputNodes[0]), true);
assert.equal(rules.isOutputDevice(outputNodes[2]), false);
assert.equal(rules.isOutputDevice(outputNodes[3]), false);
assert.equal(rules.isOutputDevice({ id: 90, ready: true, isSink: true, isStream: false,
    audio: { volume: 0.5, muted: false }, description: "Reactive fact", properties: {} }), true);

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

let baseline = rules.presentationEvent(null,
    { key: "sink:7", available: false, volume: 0, muted: false }).next;
let readyBaseline = rules.presentationEvent(baseline,
    { key: "sink:7", available: true, volume: 0.5, muted: false });
assert.equal(readyBaseline.emit, false);
baseline = readyBaseline.next;
assert.equal(rules.presentationEvent(baseline,
    { key: "sink:7", available: true, volume: 0.6, muted: false }).emit, true);

assert.equal(rules.normalizedBluetoothAddress("54:B7:E5:89:6F:14"), "54b7e5896f14");
assert.equal(rules.normalizedBluetoothAddress("bad"), "");
const bluetoothSink = { id: 81, ready: true, isSink: true, isStream: false, audio: {},
    name: "bluez_output.54_B7_E5_89_6F_14.1",
    properties: { "api.bluez5.address": "54:B7:E5:89:6F:14" } };
const wrongBluetoothSink = { id: 82, ready: true, isSink: true, isStream: false, audio: {},
    name: "bluez_output.C4_30_18_9D_1C_C5.1", properties: {} };
assert.strictEqual(rules.bluetoothSinkFor(
    [wrongBluetoothSink, bluetoothSink], "54:B7:E5:89:6F:14"), bluetoothSink);
assert.strictEqual(rules.bluetoothSinkFor([wrongBluetoothSink], "54:B7:E5:89:6F:14"), null);
assert.strictEqual(rules.bluetoothSinkFor([
    { ...bluetoothSink, isSink: false },
], "54:B7:E5:89:6F:14"), null);

console.log("PASS Audio rules fixtures");
