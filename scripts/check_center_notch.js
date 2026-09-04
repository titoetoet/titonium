#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const helperPath = path.join(__dirname, "..", "Titonium", "Bar", "notch", "CenterNotchState.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL Center Notch state helper is missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({ Math, Number, isFinite });
vm.runInContext(source, context, { filename: helperPath });
const plain = value => JSON.parse(JSON.stringify(value));

assert.equal(context.normalizePage("unknown"), "overview", "unknown page falls back safely");
assert.equal(context.normalizePage("monitoring"), "overview",
    "System Monitoring is detached from Center");
assert.equal(context.normalizePage("notifications"), "overview",
    "retired notification route falls back to the expanded canvas");
assert.equal(context.normalizePage("banner"), "banner",
    "banner remains a distinct compact action mode");
assert.equal(context.visualState(false, "overview", 0), "compact");
assert.equal(context.visualState(false, "overview", 1), "satellite");
assert.equal(context.visualState(true, "banner", 0), "banner");
assert.equal(context.visualState(true, "overview", 0), "expanded");
const ranked = [{ id: "media", source: "media", icon: "music_note" },
    { id: "recording", source: "recording" }, { id: "ignored", source: "timer" }];
const focus = { id: "focus:daily", source: "focus", icon: "center_focus_strong",
    label: "Ship Dynamic Island" };
assert.deepEqual(plain(context.activitySlots(ranked, focus)), {
    primary: focus, secondary: ranked[0]
}, "Focus stays primary while the highest-ranked live activity becomes Satellite");
assert.deepEqual(plain(context.activitySlots([], focus)), {
    primary: focus, secondary: null
}, "Focus remains the sole compact activity when the system is idle");
const notification = { id: "notification:42", source: "notification",
    icon: "notifications", label: "New message" };
assert.deepEqual(plain(context.activitySlots(ranked, focus, notification)), {
    primary: focus, secondary: notification
}, "a current notification temporarily owns the nested segment");
assert.deepEqual(plain(context.activitySlots(ranked, focus, null, false)), {
    primary: ranked[0], secondary: ranked[1]
}, "disabling Focus promotes Media to primary and preserves another activity as secondary");
const mediaAfterTimer = [
    { id: "timer-first", source: "timer", label: "Timer" },
    { id: "media-second", source: "media", label: "Track" },
    { id: "job-third", source: "job", label: "Render" }
];
assert.deepEqual(plain(context.activitySlots(mediaAfterTimer, focus, null, false)), {
    primary: mediaAfterTimer[1], secondary: mediaAfterTimer[0]
}, "Focus-disabled selection promotes Media even when it is not first");
assert.deepEqual(plain(context.activitySlots(mediaAfterTimer, focus, notification, true)), {
    primary: focus, secondary: notification
}, "notification temporarily replaces the ordered live activity");
assert.deepEqual(plain(context.activitySlots(mediaAfterTimer, focus, null, true)), {
    primary: focus, secondary: mediaAfterTimer[0]
}, "notification expiry restores the first ordered live activity");
assert.deepEqual(plain(context.contextForActivity(ranked[0])), {
    source: "media", id: "media", title: "", icon: "music_note"
});
const richTimer = {
    id: "shared", source: "timer", label: "Build", icon: "timer",
    progress: 37, deadline: 123456, customField: "retained"
};
assert.deepEqual(plain(context.normalizeContext(richTimer)), {
    id: "shared", source: "timer", label: "Build", icon: "timer",
    progress: 37, deadline: 123456, customField: "retained", title: "Build"
}, "context normalization retains service-owned fields");
assert.equal(context.contextIdentity({ source: "timer", id: "shared" }),
    "timer\u0000shared");
assert.notEqual(
    context.contextIdentity({ source: "timer", id: "shared" }),
    context.contextIdentity({ source: "job", id: "shared" }),
    "independent sources may reuse an id"
);
const colliding = [richTimer, { id: "shared", source: "job", label: "Render" }];
assert.deepEqual(plain(context.activitySlots(colliding, null, null, false)), {
    primary: richTimer,
    secondary: colliding[1]
}, "secondary selection compares source and id together");
assert.deepEqual(plain(context.layoutProfile(1920, 1080)), {
    compactHeight: 36, primaryMinWidth: 180, primaryMaxWidth: 260, nestedMaxWidth: 320,
    gap: 8, ultrawide: false
}, "standard displays use logical 36dp geometry and a 260dp ceiling");
assert.deepEqual(plain(context.layoutProfile(2293, 960)), {
    compactHeight: 42, primaryMinWidth: 180, primaryMaxWidth: 340, nestedMaxWidth: 340,
    gap: 8, ultrawide: true
}, "scaled ultrawide displays are classified by aspect ratio, not physical pixels");
assert.equal(context.connectedBodyWidth(220, 18), 184,
    "a 220px primary includes both 18px shoulders instead of growing to 256px");
assert.equal(context.compactPrimaryWidth(120, 260), 180,
    "Satellite retains State 1 minimum width for short content");
assert.equal(context.compactPrimaryWidth(205, 260), 205,
    "Satellite preserves readable content width below the ceiling");
assert.equal(context.compactPrimaryWidth(280, 260), 260,
    "standard Satellite elides only at the shared 260dp ceiling");
assert.equal(context.compactPrimaryWidth(330, 340), 330,
    "ultrawide Satellite preserves content up to its larger ceiling");
assert.deepEqual(plain(context.dragSettlePlan(0.3, 30, 200)), {
    targetState: "banner", targetProgress: 0, duration: 117
}, "a cancelled drag settles back from its current progress");
assert.deepEqual(plain(context.dragSettlePlan(0.4, 60, 100)), {
    targetState: "expanded", targetProgress: 1, duration: 144
}, "a completed drag settles forward without snapping to one");
assert.deepEqual(plain(context.dragSettlePlan(0.9, 10, 600)), {
    targetState: "expanded", targetProgress: 1, duration: 99
}, "velocity completion uses the minimum bounded settle duration");
assert.equal(context.dragDecision(48, 0), "expanded");
assert.equal(context.dragDecision(12, 500), "expanded");
assert.equal(context.dragDecision(47, 499), "banner");
assert.equal(context.shouldAutoOpen("compact", "agent", 0), true);
assert.equal(context.shouldAutoOpen("satellite", "notification", 2), true);
assert.equal(context.shouldAutoOpen("banner", "notification", 2), false);
assert.equal(context.shouldAutoOpen("expanded", "agent", 0), false);
assert.equal(context.shouldAutoOpen("compact", "media", 3), false);
assert.equal(context.entryPage("agent"), "overview",
    "AI approval bypasses Banner and enters the expanded State 4 canvas");
assert.equal(context.entryPage("notification"), "banner",
    "non-AI contextual activity continues to use Banner");
console.log("PASS Center pill canvas and banner state fixtures");

const barRoot = path.join(__dirname, "..", "Titonium", "Bar");
const sources = Object.fromEntries([
    "CenterNotch.qml", "CenterNotchSurface.qml", "CenterPillWindow.qml", "../BarHost.qml",
].map(relative => {
    const file = path.join(barRoot, "notch", relative);
    return [relative, fs.existsSync(file) ? fs.readFileSync(file, "utf8") : ""];
}));
assert.doesNotMatch(sources["CenterNotch.qml"], /CenterNotchRail/);
assert.doesNotMatch(sources["CenterNotch.qml"], /settingsRequested/);
assert.match(sources["CenterNotchSurface.qml"], /settingsRequested/);
assert.match(sources["CenterNotch.qml"], /readonly property bool isBanner:/);
assert.match(sources["CenterNotch.qml"], /property real canvasContentProgress:/,
    "banner and canvas content must cross-fade from shared progress");
assert.match(sources["CenterNotch.qml"], /CenterNotchCoordinator\.toggleFocus\(\)/,
    "the Focus banner exposes the session Focus toggle");
assert.doesNotMatch(sources["CenterNotch.qml"],
    /id:\s*bannerLayer[\s\S]*?visible:\s*root\.agentContext[\s\S]*?id:\s*dragHandle/,
    "AI approval actions must not remain in State 3 Banner");
assert.match(sources["CenterNotch.qml"], /id:\s*expandedAgentApproval/,
    "State 4 must own the expanded AI approval presentation");
assert.match(sources["CenterNotch.qml"], /AgentApprovalCard\s*\{/,
    "State 4 reuses the complete approval action surface");
for (const fallback of ["context?.trackTitle", "context?.trackArtist",
    "context?.summary", "context?.body"]) {
    assert.ok(sources["CenterNotch.qml"].includes(fallback),
        `Banner retains frozen fallback field ${fallback}`);
}
for (const key of ["center_island.media.previous", "center_island.media.play",
    "center_island.media.pause", "center_island.media.next", "center_island.expand"]) {
    assert.ok(sources["CenterNotch.qml"].includes(key),
        `Banner control must use translated accessible name ${key}`);
}
assert.match(sources["CenterNotchSurface.qml"],
    /CenterNotchCoordinator\.openAgentApproval\(/,
    "incoming AI approval must route directly to State 4");
assert.match(sources["CenterNotchSurface.qml"],
    /CenterNotchState\.entryPage\(context\.source\)/,
    "reopening a pending AI approval from the compact pill must still enter State 4");
assert.match(sources["CenterNotchSurface.qml"], /property real transitionProgress:/,
    "compact and open content must follow one reversible progress value");
assert.match(sources["CenterNotchSurface.qml"], /visible:\s*root\.compactContentOpacity > 0/,
    "compact content must remain mounted during the geometry morph");
assert.match(sources["CenterNotchSurface.qml"], /visible:\s*root\.openContentOpacity > 0/,
    "open content must enter from the shared transition progress");
assert.doesNotMatch(sources["CenterNotchSurface.qml"],
    /scale:\s*1\s*-\s*root\.transitionProgress\s*\*\s*0\.03/,
    "compact text and icons must not shrink during the surface morph");
const centerIslandSource = fs.readFileSync(path.join(barRoot, "islands", "CenterIsland.qml"), "utf8");
assert.doesNotMatch(centerIslandSource, /Behavior on implicit(Width|Height)/,
    "compact content must publish one target size instead of animating geometry internally");
assert.doesNotMatch(centerIslandSource, /sizeMorphEnabled|syncIslandGeometry/,
    "legacy per-frame geometry synchronization must stay removed");
assert.match(centerIslandSource, /CenterNotchCoordinator\.setCompactWidth\(root\.implicitWidth\)/,
    "compact content publishes only its width target to the visual owner");
assert.match(centerIslandSource,
    /id:\s*focusToggle[\s\S]*?CenterNotchCoordinator\.toggleFocus\(\)/,
    "the compact Focus icon toggles session mode without opening Banner");
for (const key of ["center_island.focus.enable", "center_island.focus.disable"]) {
    assert.ok(centerIslandSource.includes(key),
        `compact Focus target uses translated accessibility key ${key}`);
}
assert.equal((sources["CenterNotchSurface.qml"].match(/Shared\.ConnectedPillShape\s*\{/g) || []).length, 1,
    "popup must render one connected silhouette");
assert.match(sources["CenterPillWindow.qml"], /visible: true/,
    "one screen-local owner remains mounted across every state");
assert.match(sources["CenterPillWindow.qml"],
    /visible:\s*!window\.ownsIsland\s*&&\s*!window\.dismissing/,
    "both styles expose the shared compact Center input region");
assert.match(sources["CenterPillWindow.qml"],
    /width:\s*!window\.ownsIsland\s*\?\s*surface\.compactInputWidth\s*:\s*0/,
    "the shared owner supplies the compact Center mask");
assert.match(sources["CenterPillWindow.qml"],
    /WlrLayershell\.keyboardFocus:\s*window\.ownsIsland[\s\S]*?WlrKeyboardFocus\.None/,
    "Classic mode must retain no Center keyboard focus");
assert.doesNotMatch(sources["CenterPillWindow.qml"], /Loader\s*\{/);
assert.match(sources["CenterNotchSurface.qml"],
    /StartIsland\s*\{[\s\S]*?visible:\s*root\.ownsIsland/,
    "an open Center must retain interactive left-pill controls in its owning window");
assert.match(sources["CenterNotchSurface.qml"],
    /EndIsland\s*\{[\s\S]*?visible:\s*root\.ownsIsland/,
    "an open Center must retain interactive right-pill controls in its owning window");
assert.doesNotMatch(sources["CenterNotchSurface.qml"], /RoundCorner/);
assert.doesNotMatch(sources["CenterNotchSurface.qml"], /filler|seam/i);
assert.doesNotMatch(sources["CenterNotchSurface.qml"], /id:\s*satelliteBubble/,
    "State 2 must not restore a detached satellite bubble");
assert.match(sources["CenterNotchSurface.qml"], /id:\s*nestedSatellite/,
    "State 2 keeps the secondary hitbox inside the monolithic pill");
assert.match(sources["CenterNotchSurface.qml"], /id:\s*nestedEqualizer/,
    "Music uses a live equalizer in the nested segment");
assert.match(sources["CenterNotchSurface.qml"],
    /model:\s*\[4, 7, 5, 8, 3\]/,
    "the nested equalizer owns five independently animated bars");
assert.match(sources["CenterNotchSurface.qml"],
    /running:\s*root\.satelliteDesired\s*&&\s*nestedEqualizer\.visible\s*&&\s*!Motion\.reduced/,
    "the equalizer must stop when Music is hidden or Reduced Motion is active");
assert.match(sources["CenterNotchSurface.qml"], /id:\s*nestedNotificationIcon/,
    "notification uses the nested wobble presentation");
assert.doesNotMatch(sources["CenterNotchSurface.qml"],
    /id:\s*nestedSatellite[\s\S]*?border\.width[\s\S]*?HoverHandler/,
    "the nested segment must remain borderless");
assert.match(sources["CenterNotchSurface.qml"], /id:\s*nestedExitRelease/,
    "nested width release must not depend on an interruptible opacity callback");
assert.match(centerIslandSource,
    /CenterAttentionService\.presentation\?\.source === "media"/,
    "media events must not displace Focus from the primary segment");
assert.equal(fs.existsSync(path.join(barRoot, "islands", "CenterGroup.qml")), false,
    "legacy compact visual owner is removed");
assert.equal(fs.existsSync(path.join(barRoot, "islands", "NotificationPill.qml")), false,
    "legacy unread-notification satellite is removed");
assert.equal(fs.existsSync(path.join(barRoot, "widgets", "NotificationBell.qml")), true,
    "conditional notification bell is integrated into the unified right pill");
for (const retired of [
    "CenterNotchViewport.qml", "OverviewPage.qml", "OverviewWeatherHero.qml",
    "OverviewFocusCard.qml", "OverviewMediaCard.qml", "NotificationsPage.qml",
    "NotificationHistoryRow.qml",
]) {
    assert.equal(fs.existsSync(path.join(barRoot, "notch", retired)), false,
        `${retired} must not survive the clean-canvas replacement`);
}
console.log("PASS Center Notch owns the rewritten banner and expanded canvas");
