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

for (const file of ["CenterRenderer.qml", ...["Pill", "Notch", "Connected", "Classic"]
    .flatMap(name => [`presentations/${name}/${name}Renderer.qml`,
        `presentations/${name}/${name}Profile.js`])])
    assert.equal(fs.existsSync(path.join(path.dirname(rulesPath), file)), true, `missing ${file}`);
const renderer = fs.readFileSync(path.join(path.dirname(rulesPath),
    "presentations/Connected/ConnectedRenderer.qml"), "utf8");
assert.match(renderer, /Shared\.ConnectedPillShape\s*\{/,
    "Center must render the shared symmetric top-connected shoulder contour");
assert.match(renderer,
    /Shared\.SystemIcon\s*\{[\s\S]*?sourceName:\s*root\.context\?\.icon\s*\|\|\s*""[\s\S]*?fallbackName:\s*root\.context\?\.icon\s*\|\|\s*"center_focus_strong"/,
    "Center context icons must render image paths while retaining semantic glyph fallbacks");
for (const fragment of ["bodyWidth: root.bodyWidth", "shoulderSize: root.shoulderSize",
        "readonly property rect visualBounds: Qt.rect(shape.x, shape.y, shape.width, shape.height)"])
    assert.ok(renderer.includes(fragment), `Center contour contract missing: ${fragment}`);
for (const fragment of ["required property var snapshot", "required property var viewState",
    "required property var profile", "signal intentRequested(var intent)",
    "signal transitionFinished(int generation)", "readonly property rect visualBounds",
    "readonly property rect interactiveBounds"])
    assert.ok(renderer.includes(fragment), `Connected renderer missing ${fragment}`);
assert.doesNotMatch(renderer, /Services\.(Capture|Mpris|Notifications|AgentApproval|Center)/);
assert.doesNotMatch(renderer, /\b(Process|FileView|Timer)\s*\{/);
console.log("PASS Connected renderer exposes neutral state and intent contract");

for (const legacy of ["CenterNotchCoordinator.qml", "CenterNotchSurface.qml",
    "CenterNotch.qml", "CenterPillWindow.qml"]) {
    assert.equal(fs.existsSync(path.join(root, "Titonium", "Bar", "notch", legacy)), false,
        `legacy Center owner remains: ${legacy}`);
}
console.log("PASS presentation profiles replace legacy Center ownership");
