#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Mpris", "MprisRules.js");

if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing Titonium/Services/Mpris/MprisRules.js");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

const playing = {
    identity: "player.a",
    playbackState: "playing",
    trackTitle: "Awake",
    trackArtist: "Tycho",
    desktopEntry: "spotify",
    changedAt: 20,
};
const paused = {
    identity: "player.b",
    playbackState: "paused",
    trackTitle: "Other",
    trackArtist: "Artist",
    desktopEntry: "player-b",
    changedAt: 40,
};

assert.equal(rules.select([paused, playing]).identity, "player.a");
assert.equal(rules.select([
    { ...paused, identity: "player.z", changedAt: 50 },
    { ...paused, identity: "player.a", changedAt: 60 },
]).identity, "player.a");
assert.equal(rules.select([
    { ...paused, identity: "player.z", changedAt: 60 },
    { ...paused, identity: "player.a", changedAt: 60 },
]).identity, "player.a");
assert.equal(rules.select([
    { ...playing, identity: "player.playing" },
    { ...paused, identity: "player.paused", changedAt: 999 },
]).identity, "player.playing");
console.log("PASS playing rank, recency and stable identity selection");

const normalized = rules.normalizePlayer({
    identity: " player.native ",
    playbackState: "Playing",
    trackTitle: "  A Walk  ",
    trackArtist: [" Tycho ", " Saint Sinner "],
    desktopEntry: " org.music.Player ",
    changedAt: 42,
    trackLength: 0,
    trackPosition: 0,
    nativeObject: { dangerous: true },
});
assert.deepEqual(plain(normalized), {
    identity: "player.native",
    playbackState: "playing",
    trackTitle: "A Walk",
    trackArtist: "Tycho, Saint Sinner",
    title: "Tycho, Saint Sinner · A Walk",
    desktopEntry: "org.music.Player",
    trackArtUrl: "",
    trackLength: 0,
    trackPosition: 0,
    canTogglePlaying: false,
    canGoPrevious: false,
    canGoNext: false,
    trackLength: 0,
    trackPosition: 0,
    changedAt: 42,
});
assert.equal(Object.isFrozen(normalized), true);
assert.equal(rules.normalizePlayer({ identity: "", playbackState: "playing" }), null);
assert.equal(rules.normalizePlayer({ identity: "x", playbackState: "unknown" }).playbackState,
    "stopped");
assert.equal(rules.indicatorActive(playing), true);
assert.equal(rules.indicatorActive(paused), false);
assert.equal(rules.indicatorActive({ ...playing, playbackState: "stopped" }), false);
assert.equal(rules.indicatorActive(null), false);
console.log("PASS native facts normalize into frozen value descriptors");

assert.deepEqual(plain(rules.activity(playing, 2000)), {
    id: "media:current",
    source: "media",
    label: "Tycho · Awake",
    icon: "music_note",
    importance: "normal",
    progress: -1,
    deadline: 0,
    updatedAt: 2000,
    trackLength: 0,
    trackPosition: 0,
});
assert.equal(rules.activity(paused, 3000), null);
assert.equal(rules.activity({ ...playing, trackTitle: "" }, 4000), null);
console.log("PASS only actively playing Media projects a persistent Center activity");

const baseline = rules.transition(null, playing, 1000);
assert.equal(baseline.event, null);
assert.equal(baseline.next.title, "Tycho · Awake");
const changed = rules.transition(baseline.next, {
    ...playing,
    trackTitle: "A Walk",
    changedAt: 30,
}, 2000);
assert.deepEqual(plain(changed.event), {
    id: "media:current",
    deduplicationKey: "media:current",
    source: "media",
    kind: "track_changed",
    title: "Tycho · A Walk",
    icon: "music_note",
    createdAt: 2000,
});
console.log("PASS discovery establishes baseline and later track change publishes once");

const pausedTransition = rules.transition(baseline.next, {
    ...playing,
    playbackState: "paused",
    changedAt: 21,
}, 3000);
assert.equal(pausedTransition.event.kind, "paused");
assert.equal(pausedTransition.event.title, "Tycho · Awake");
const resumedTransition = rules.transition(pausedTransition.next, {
    ...playing,
    playbackState: "playing",
    changedAt: 22,
}, 4000);
assert.equal(resumedTransition.event.kind, "resumed");
assert.equal(resumedTransition.event.createdAt, 4000);
console.log("PASS pause and resume emit semantic transitions");

const changedWhileResuming = rules.transition(pausedTransition.next, {
    ...playing,
    playbackState: "playing",
    trackTitle: "Hours",
    changedAt: 23,
}, 5000);
assert.equal(changedWhileResuming.event.kind, "track_changed");
assert.equal(changedWhileResuming.event.title, "Tycho · Hours");
console.log("PASS track change takes precedence over simultaneous playback change");

const duplicate = rules.transition(baseline.next, {
    ...playing,
    playbackState: "PLAYING",
    trackTitle: " Awake ",
    trackArtist: ["Tycho"],
    changedAt: 999,
}, 6000);
assert.equal(duplicate.event, null);
assert.equal(rules.signature(duplicate.next), rules.signature(baseline.next));
assert.equal(rules.transition(baseline.next, null, 7000).event, null);
assert.equal(rules.transition(baseline.next, null, 7000).next, null);
assert.equal(rules.transition(baseline.next, {
    ...playing,
    playbackState: "stopped",
    trackTitle: "",
    changedAt: 1000,
}, 8000).event, null);
assert.equal(rules.transition(baseline.next, {
    ...playing,
    trackTitle: "",
    changedAt: 1001,
}, 9000).event, null);
console.log("PASS duplicate, disappearance, stop and blank-title changes stay silent");
