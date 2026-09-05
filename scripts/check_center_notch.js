#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");

const controller = read("Titonium/Core/Surfaces/Center/CenterSurfaceController.qml");
const host = read("Titonium/Core/Surfaces/Center/CenterSurfaceHost.qml");
const compact = read("Titonium/Core/Surfaces/Center/CenterCompactWindow.qml");
const overlay = read("Titonium/Core/Surfaces/Center/CenterOverlayWindow.qml");
const renderer = read("Titonium/Bar/center/CenterRenderer.qml");
const connected = read("Titonium/Bar/center/presentations/Connected/ConnectedRenderer.qml");

assert.match(controller, /readonly property string mode:/);
assert.match(controller, /readonly property string selectedContextId:/);
assert.match(controller, /readonly property string presentationOwner:/);
assert.match(controller, /readonly property var viewState: Object\.freeze\(/);
assert.match(controller, /deadlineToken: root\.internalState\.deadlineToken/);
assert.match(controller, /property bool automaticPresentationAvailable:/);
assert.match(controller, /readonly property bool automaticPresentationEligible:/);
assert.match(controller, /CenterSurfaceState\.automaticPresentationEligible/);
assert.match(controller, /intent\.type === "set-presentation-available"/);
assert.match(controller, /CenterDomain\.setPresentationEligible/);
assert.match(controller, /CenterSurfaceState\.pauseDeadline/);
assert.match(controller, /CenterSurfaceState\.resumeDeadline/);
assert.match(controller, /CenterDomain\.completePresentation/);
assert.match(controller, /CenterSurfaceState\.applyPresentationResult/);
assert.match(controller,
    /intent\.type === "user-dismiss-presentation"[\s\S]*?CenterSurfaceState\.timedPresentationMatches\(root\.internalState, intent\)[\s\S]*?root\.completeActivePresentation\(intent\.contextId, now\)/,
    "user dismissal must complete the exact generic timed presentation");
assert.match(controller,
    /intent\.type === "pause-timeout"[\s\S]*?CenterSurfaceState\.deadlineMatches\(root\.internalState, intent, now\)[\s\S]*?root\.completeActivePresentation\(intent\.contextId, now\)[\s\S]*?CenterSurfaceState\.pauseDeadline/,
    "hover arriving at an elapsed exact deadline must complete that presentation");
for (const scheduledField of ["scheduledDeadlineGeneration",
    "scheduledDeadlineContextId", "scheduledDeadline"])
    assert.match(controller, new RegExp(`property .* ${scheduledField}:`));
assert.match(controller,
    /root\.scheduledDeadlineGeneration = root\.internalState\.generation/);
assert.match(controller,
    /root\.scheduledDeadlineContextId = root\.internalState\.selectedContextId/);
assert.match(controller, /root\.scheduledDeadline = root\.internalState\.deadline/);
assert.match(controller, /function scheduledDeadlineIntent\(\): var/);
assert.doesNotMatch(controller,
    /onTriggered:[^\n]*generation: root\.generation|Qt\.callLater\(\(\) => root\.dispatch\(\{ type: "timeout", generation: root\.generation/,
    "deadline callbacks must dispatch the identity captured when the timer was scheduled");
assert.match(controller, /function onPresentationEnded\(request: var\): void/);
assert.match(controller, /request\.acquisitionPolicy === "non-preemptive"/);
assert.match(controller, /acquisitionPolicy: request\.acquisitionPolicy/);
assert.doesNotMatch(controller, /["']notification["']|criticalPresentationEligible/,
    "Core Center controller must not branch on notification source identity");
assert.match(host, /CenterCompactWindow\s*\{/);
assert.match(host, /CenterOverlayWindow\s*\{/);
assert.match(host, /snapshot: CenterDomain\.snapshot/);
assert.match(host,
    /Component\.onDestruction:[\s\S]*?CenterSurfaceController\.ownerScreenName === root\.screenModel\.name[\s\S]*?type: "surface-revoked"/,
    "losing the eligible Center host must revoke automatic presentation availability");
assert.match(compact, /WlrLayershell\.keyboardFocus: WlrKeyboardFocus\.None/);
assert.match(compact, /transitionOwner:\s*false/,
    "compact Center window must never own Classic popup transitions");
assert.match(compact, /presentationActive:\s*window\.ownsCompact/);
assert.match(compact,
    /mask: Region \{[\s\S]*?id: inputMask[\s\S]*?Region \{ item: inputRegion \}[\s\S]*?\}/);
assert.match(compact, /x: renderer\.interactiveBounds\.x/);
assert.match(overlay,
    /window\.viewState\.focusPolicy === "exclusive"[\s\S]*?WlrKeyboardFocus\.Exclusive/);
assert.match(overlay, /CenterSurfaceController\.finishClose\(/);
assert.doesNotMatch(overlay, /transitionOwner:\s*true/,
    "overlay transition ownership must never be unconditional");
assert.match(overlay,
    /readonly property bool classicTransitionOwner:[\s\S]*?PresentationRules\.transitionOwner\(window\.viewState, window\.screenModel\.name\)[\s\S]*?window\.classicTransitionPending/);
assert.match(overlay, /transitionOwner:\s*window\.classicTransitionOwner/);
assert.match(overlay,
    /presentationActive:\s*window\.ownsOverlay \|\| window\.dismissing[\s\S]*?window\.classicTransitionPending/);
assert.match(overlay,
    /visible:\s*window\.ownsOverlay \|\| window\.dismissing \|\| window\.classicTransitionPending/);
assert.match(overlay,
    /function closeIntent\(\): var[\s\S]*?window\.viewState\.mode === "banner"[\s\S]*?window\.viewState\.dismissalPolicy === "timed"[\s\S]*?type: "user-dismiss-presentation"/,
    "timed banner Escape/outside dismissal must be distinct from compact navigation");
assert.equal((overlay.match(/CenterSurfaceController\.dispatch\(window\.closeIntent\(\)\)/g) || []).length,
    2, "outside click and Escape must share the user-dismiss presentation intent");

for (const profile of ["Pill", "Notch", "Connected", "Classic"])
    assert.match(renderer, new RegExp(`${profile}\\.${profile}Renderer`));
assert.match(connected, /required property var snapshot/);
assert.match(connected, /required property var viewState/);
assert.match(connected, /required property var profile/);
assert.match(connected, /signal intentRequested\(var intent\)/);
assert.match(connected, /type: "invoke-action"/);
assert.match(renderer, /required property bool transitionOwner/);
assert.match(renderer, /required property bool presentationActive/);
assert.match(renderer,
    /transitionOwner:\s*root\.transitionOwner && root\.profile\.id === "classic"/,
    "inactive Classic renderers must never receive transition ownership");

const router = read("Titonium/Orchestration/SurfaceRouter.qml");
assert.match(router, /function automaticCenterPresentationAvailable\(\): bool/);
assert.match(router, /function syncAutomaticCenterPresentation\(\): void/);
assert.match(router, /request\.acquisitionPolicy === "non-preemptive"/);
assert.match(router, /CenterSurfaceController\.automaticPresentationEligible/);
assert.match(router,
    /target: ScreenPolicy[\s\S]*?function onScreensChanged\(\): void[\s\S]*?root\.syncAutomaticCenterPresentation\(\)/,
    "automatic presentation availability must resynchronize with screen lifecycle");
assert.doesNotMatch(router,
    /\bNotificationService\b|\bNotificationCoordinator\b|["']notification["']/,
    "surface arbitration must stay behind the neutral controller/domain adapter boundary");

for (const legacy of [
    "Titonium/Bar/notch/CenterNotchCoordinator.qml",
    "Titonium/Bar/notch/CenterNotchState.js",
    "Titonium/Bar/notch/CenterNotchSurface.qml",
    "Titonium/Bar/notch/CenterNotch.qml",
    "Titonium/Bar/notch/CenterPillWindow.qml",
    "Titonium/Bar/islands/CenterIsland.qml",
]) {
    assert.equal(fs.existsSync(path.join(root, legacy)), false,
        `${legacy} must not survive the neutral Center cutover`);
}

console.log("PASS neutral Center host and renderer integration");
