#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Bar", "center",
    "CenterPresentationRules.js");

if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing CenterPresentationRules.js");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

assert.equal(rules.leadingIcon({
    source: "clipboard",
    icon: "content_copy",
    title: "Đã sao chép · hello",
}, { icon: "work" }), "content_copy");
assert.equal(rules.leadingIcon({
    source: "notification",
    icon: "notifications",
    title: "Bạn có một notification",
}, null), "notifications");
assert.equal(rules.leadingIcon(null, { icon: "work" }), "work");
assert.equal(rules.leadingIcon(null, null), "center_focus_strong");
assert.equal(rules.leadingIcon(null, null, [
    { id: "notification", icon: "mark_email_unread" },
    { id: "media", icon: "music_note" },
]), "center_focus_strong");
assert.equal(rules.leadingIcon({ icon: "   " }, null), "center_focus_strong");
console.log("PASS each Center presentation owns exactly one matching icon");

function plain(value) { return JSON.parse(JSON.stringify(value)); }
for (const style of ["pill", "notch", "connected", "classic"]) {
    const profile = rules.profile(style);
    assert.equal(profile.id, style);
    assert.ok(Object.isFrozen(profile));
    assert.ok(Object.isFrozen(profile.capabilities));
}
const connected = rules.profile("connected");
assert.deepEqual(plain(connected.compact),
    { inset: 4, minWidth: 160, maxWidth: 480, height: 32, radius: 16 });
assert.equal(rules.geometry(connected, { width: 360, height: 800 }, "expanded").width, 320);
assert.equal(rules.profile("invalid").id, "connected");
console.log("PASS four Center presentation profiles provide frozen clamped geometry");

const classic = rules.profile("classic");
assert.deepEqual(plain(classic.transitions), {
    open: "popup", close: "popup", contextChange: "crossfade",
});
assert.deepEqual(plain(rules.classicPopupGeometry(
    classic, { width: 1920, height: 1080 }, "banner", 44, 8)), {
    x: 720, y: 52, width: 480, height: 72, radius: 22,
});
assert.deepEqual(plain(rules.classicPopupGeometry(
    classic, { width: 1920, height: 1080 }, "expanded", 44, 8)), {
    x: 600, y: 52, width: 720, height: 440, radius: 28,
});
assert.deepEqual(plain(rules.classicPopupMotion("open", false)), {
    opacityFrom: 0, opacityTo: 1, opacityMs: 150,
    scaleFrom: 0.94, scaleTo: 1, scaleMs: 220,
    yFrom: -12, yTo: 0, yMs: 220,
});
assert.deepEqual(plain(rules.classicPopupMotion("close", false)), {
    opacityFrom: 1, opacityTo: 0, opacityMs: 120,
    scaleFrom: 1, scaleTo: 0.96, scaleMs: 130,
    yFrom: 0, yTo: -8, yMs: 130,
});
assert.deepEqual(plain(rules.classicPopupMotion("open", true)), {
    opacityFrom: 1, opacityTo: 1, opacityMs: 0,
    scaleFrom: 1, scaleTo: 1, scaleMs: 0,
    yFrom: 0, yTo: 0, yMs: 0,
});
assert.deepEqual(plain(rules.geometry(classic,
    { width: 1920, height: 1080 }, "compact")), {
    x: 880, y: 8, width: 160, height: 36, radius: 16,
});
assert.deepEqual(plain(rules.geometry(connected,
    { width: 1920, height: 1080 }, "banner")), {
    x: 720, y: 0, width: 480, height: 72, radius: 22,
});
console.log("PASS Classic detaches every open mode while compact and Connected stay unchanged");

assert.equal(typeof rules.combinedVisualBounds, "function",
    "Center presentation rules must expose visible-secondary bounds composition");
assert.deepEqual(plain(rules.combinedVisualBounds(
    { x: 850, y: 0, width: 220, height: 32 },
    { x: 1070, y: 0, width: 52, height: 32 }, true)),
{ x: 850, y: 0, width: 272, height: 32 },
"Connected visual bounds must include the joined visible secondary pill");
assert.deepEqual(plain(rules.combinedVisualBounds(
    { x: 850, y: 8, width: 220, height: 36 },
    { x: 1078, y: 8, width: 52, height: 36 }, true)),
{ x: 850, y: 8, width: 280, height: 36 },
"Classic visual bounds must include its detached visible secondary pill and gap");
assert.deepEqual(plain(rules.combinedVisualBounds(
    { x: 850, y: 8, width: 220, height: 36 },
    { x: 1078, y: 8, width: 52, height: 36 }, false)),
{ x: 850, y: 8, width: 220, height: 36 },
"a hidden secondary pill must not expand exported visual bounds");
console.log("PASS Center visual bounds include only a visible secondary pill");

const firstBannerGeometry = rules.geometry(connected, { width: 1920, height: 1080 }, "banner");
const nextBannerGeometry = rules.geometry(connected, { width: 1920, height: 1080 }, "banner");
assert.deepEqual(plain(firstBannerGeometry), {
    x: 720, y: 0, width: 480, height: 72, radius: 22,
});
assert.deepEqual(plain(nextBannerGeometry), plain(firstBannerGeometry));
assert.deepEqual(plain(rules.contextTransition(connected, false)), {
    kind: "crossfade", exitMs: 80, enterMs: 120,
});
assert.deepEqual(plain(rules.contextTransition(connected, true)), {
    kind: "replace", exitMs: 0, enterMs: 0,
});
console.log("PASS FIFO content changes preserve banner geometry and honor Reduced Motion");

const secondaryFailures = [];
function checkSecondaryTransition(name, previous, indicator, expected) {
    const actual = typeof rules.secondaryIndicatorTransition === "function"
        ? rules.secondaryIndicatorTransition(previous, indicator) : null;
    try {
        assert.deepEqual(plain(actual), expected);
    } catch (error) {
        secondaryFailures.push(`${name}: ${error.message}`);
    }
    return actual;
}
checkSecondaryTransition("first 0-to-1 activation wobbles", null, {
    active: true, count: 1, revision: 1,
}, { observation: { count: 1, revision: 1 }, wobble: true });
const clearedSecondary = checkSecondaryTransition("5-to-0 clear does not wobble", {
    count: 5, revision: 5,
}, { active: false, count: 0, revision: 6 }, {
    observation: { count: 0, revision: 6 }, wobble: false,
});
checkSecondaryTransition("0-to-1 reactivation during exit wobbles",
    clearedSecondary?.observation || null,
    { active: true, count: 1, revision: 7 }, {
        observation: { count: 1, revision: 7 }, wobble: true,
    });
assert.deepEqual(secondaryFailures, [], secondaryFailures.join("\n"));
console.log("PASS secondary indicator motion observes first activation and exit reactivation");

for (const file of ["CenterRenderer.qml", ...["Pill", "Notch", "Connected", "Classic"]
    .flatMap(name => [`presentations/${name}/${name}Renderer.qml`,
        `presentations/${name}/${name}Profile.js`])])
    assert.equal(fs.existsSync(path.join(path.dirname(rulesPath), file)), true, `missing ${file}`);
const centerRoot = path.dirname(rulesPath);
const secondaryPillPath = path.join(centerRoot, "CenterSecondaryPill.qml");
assert.equal(fs.existsSync(secondaryPillPath), true,
    "Center must own a focused secondary-pill presentation component");
const secondaryPill = fs.readFileSync(secondaryPillPath, "utf8");
const centerQmldir = fs.readFileSync(path.join(centerRoot, "qmldir"), "utf8");
assert.match(centerQmldir, /CenterSecondaryPill 1\.0 CenterSecondaryPill\.qml/,
    "Center qmldir must export its secondary pill");
for (const fragment of [
    "required property var indicator",
    "required property bool rendererVisible",
    "readonly property rect visualBounds",
    "readonly property rect interactiveBounds",
    'name: "notifications"',
    "root.displayedIndicator.count",
    "root.displayedIndicator.accessibleName",
    "loops: 3",
    "Motion.reduced",
    "wobble.stop()",
    "PresentationRules.secondaryIndicatorTransition",
    "property var indicatorObservation",
])
    assert.ok(secondaryPill.includes(fragment),
        `Center secondary pill missing bounded presentation behavior: ${fragment}`);
assert.doesNotMatch(secondaryPill,
    /Services\.Notifications|NotificationCoordinator|NotificationService/,
    "Center secondary pill must consume only immutable indicator data");
assert.doesNotMatch(secondaryPill, /TapHandler|MouseArea|onClicked|intentRequested/,
    "Center secondary pill must not add notification-history click behavior");
assert.doesNotMatch(secondaryPill, /ConnectedPillShape|shoulderSize/,
    "Center secondary pill must not own Connected concave shoulders");
assert.doesNotMatch(secondaryPill, /Animation\.Infinite/,
    "Center secondary motion must always be bounded");
assert.match(secondaryPill,
    /function clearPresentation\(\): void\s*\{[\s\S]*?exitAnimation\.stop\(\)[\s\S]*?root\.stopMotion\(\)/,
    "hidden and Reduced Motion clears must stop the exit animation as well as wobble");

const renderer = fs.readFileSync(path.join(path.dirname(rulesPath),
    "presentations/Connected/ConnectedRenderer.qml"), "utf8");
assert.match(renderer, /Shared\.ConnectedPillShape\s*\{/,
    "Center must render the shared symmetric top-connected shoulder contour");
assert.match(renderer,
    /Shared\.SystemIcon\s*\{[\s\S]*?sourceName:\s*root\.displayedContext\?\.icon\s*\|\|\s*""[\s\S]*?fallbackName:\s*root\.displayedContext\?\.icon\s*\|\|\s*"center_focus_strong"/,
    "Center context icons must render image paths while retaining semantic glyph fallbacks");
for (const fragment of ["bodyWidth: root.bodyWidth", "shoulderSize: root.shoulderSize"])
    assert.ok(renderer.includes(fragment), `Center contour contract missing: ${fragment}`);
for (const fragment of ["required property var snapshot", "required property var viewState",
    "required property var profile", "signal intentRequested(var intent)",
    "signal transitionFinished(int generation)", "readonly property rect visualBounds",
    "readonly property rect interactiveBounds"])
    assert.ok(renderer.includes(fragment), `Connected renderer missing ${fragment}`);
for (const fragment of ["property var displayedContext", "id: contentStage",
    "SequentialAnimation", "PresentationRules.contextTransition",
    "HoverHandler", '"pause-timeout"', '"resume-timeout"',
    "function deadlineIntent(type: string): var", "generation: root.viewState.generation",
    "contextId: root.viewState.selectedContextId",
    "deadline: root.viewState.deadlineToken", "id: activationArea", "id: actionRow",
    "parent: activationArea", "gesturePolicy: TapHandler.ReleaseWithinBounds",
    'I18n.tr("menubar.center.title")'])
    assert.ok(renderer.includes(fragment), `Connected renderer missing FIFO presentation: ${fragment}`);
assert.doesNotMatch(renderer, /\|\| "Center"/,
    "Center fallback labels must use the locale service");
assert.doesNotMatch(renderer, /Loader\s*\{/,
    "FIFO content replacement must not replace the mounted banner owner");
assert.doesNotMatch(renderer, /Services\.(Capture|Mpris|Notifications|AgentApproval|Center)/);
assert.doesNotMatch(renderer, /\b(Process|FileView|Timer)\s*\{/);
assert.match(renderer, /CenterSecondaryPill\s*\{/,
    "Connected Center must compose the notification secondary pill");
for (const fragment of [
    'item => item.id === "notification:unread"',
    "indicator: root.notificationIndicator",
    "rendererVisible: root.visible",
    "x: shape.x + shape.width",
    "readonly property rect primaryVisualBounds:",
    "PresentationRules.combinedVisualBounds(root.primaryVisualBounds,",
    "secondaryPill.visualBounds, secondaryPill.visible)",
    "readonly property rect interactiveBounds: root.primaryVisualBounds",
])
    assert.ok(renderer.includes(fragment),
        `Connected secondary-pill composition missing: ${fragment}`);
console.log("PASS Connected renderer exposes neutral state and intent contract");

const classicRenderer = fs.readFileSync(path.join(path.dirname(rulesPath),
    "presentations/Classic/ClassicRenderer.qml"), "utf8");
assert.doesNotMatch(classicRenderer,
    /Connected\.ConnectedRenderer|ConnectedPillShape|shoulderSize/,
    "Classic renderer must not reuse Connected shoulder geometry");
assert.match(classicRenderer, /Shared\.Surface\s*\{/,
    "Classic renderer must render its own rounded surface");
assert.match(classicRenderer,
    /readonly property rect visualBounds:[\s\S]*?classicBody/,
    "Classic renderer must expose bounds from its own body");
for (const fragment of ["required property var snapshot", "required property var viewState",
    "required property var profile", "signal intentRequested(var intent)",
    "signal transitionFinished(int generation)", "readonly property rect visualBounds",
    "readonly property rect interactiveBounds"])
    assert.ok(classicRenderer.includes(fragment), `Classic renderer missing ${fragment}`);
assert.match(classicRenderer, /CenterSecondaryPill\s*\{/,
    "Classic Center must compose the notification secondary pill");
for (const fragment of [
    'item => item.id === "notification:unread"',
    "indicator: root.notificationIndicator",
    "rendererVisible: root.visible",
    "x: classicBody.x + classicBody.width + Metrics.spacingSmall",
    "readonly property rect primaryVisualBounds:",
    "PresentationRules.combinedVisualBounds(root.primaryVisualBounds,",
    "secondaryPill.visualBounds, secondaryPill.visible)",
    "readonly property rect interactiveBounds: root.primaryVisualBounds",
])
    assert.ok(classicRenderer.includes(fragment),
        `Classic secondary-pill composition missing: ${fragment}`);
assert.doesNotMatch(classicRenderer, /secondary[\s\S]*?ConnectedPillShape/,
    "Classic secondary pill must remain detached and shoulder-free");
for (const fragment of [
    "readonly property bool popupMode:",
    "readonly property real popupTop: Metrics.barHeight + Metrics.barSpacing",
    "Shared.Panel {",
    "customColor: Theme.surface",
    "id: popupEntranceOffset",
    "id: popupEntrance",
    "id: popupExit",
    "PresentationRules.classicPopupMotion",
    "property int transitionGeneration",
    "root.transitionFinished(root.transitionGeneration)",
    "rendererVisible: root.visible && root.viewState.mode === \"compact\"",
    "&& !root.popupClosing",
])
    assert.ok(classicRenderer.includes(fragment),
        `Classic detached popup contract missing: ${fragment}`);
assert.match(classicRenderer,
    /anchors\.topMargin:\s*root\.popupTop/,
    "Classic banner and expanded popup must share the detached Topbar gap");
assert.doesNotMatch(classicRenderer,
    /Behavior on (width|height)/,
    "Classic must not morph popup geometry from the compact pill");
assert.match(classicRenderer,
    /function beginPopupExit\(generation: int\): void[\s\S]*?root\.transitionGeneration = generation[\s\S]*?popupExit\.restart\(\)/,
    "Classic close must capture the controller generation before its detached exit");
assert.match(classicRenderer,
    /NumberAnimation\s*\{[\s\S]*?target:\s*popupPanel[\s\S]*?property:\s*"opacity"[\s\S]*?duration:\s*root\.closeMotion\.opacityMs/,
    "Classic popup close must use the shared popup opacity timing");
for (const [source, label] of [[renderer, "Connected"], [classicRenderer, "Classic"]])
    assert.doesNotMatch(source, /readonly property rect interactiveBounds:\s*root\.visualBounds/,
        `${label} secondary visuals must not expand the primary-only input bounds`);
console.log("PASS Classic renderer keeps the neutral contract without Connected shoulders");

const topbarBell = fs.readFileSync(path.join(root, "Titonium", "Bar", "widgets",
    "NotificationBell.qml"), "utf8");
assert.doesNotMatch(topbarBell,
    /SequentialAnimation|ParallelAnimation|property:\s*"rotation"|loops:\s*3/,
    "the fixed Topbar history control must contain no bell animation");
console.log("PASS notification motion belongs only to the Center secondary pill");

for (const legacy of ["CenterNotchCoordinator.qml", "CenterNotchSurface.qml",
    "CenterNotch.qml", "CenterPillWindow.qml"]) {
    assert.equal(fs.existsSync(path.join(root, "Titonium", "Bar", "notch", legacy)), false,
        `legacy Center owner remains: ${legacy}`);
}
console.log("PASS presentation profiles replace legacy Center ownership");
