.pragma library

var STYLES = Object.freeze({ pill: true, notch: true, connected: true, classic: true });

function leadingIcon(eventPresentation, activityPresentation) {
    var value = eventPresentation && eventPresentation.icon
        ? String(eventPresentation.icon).trim() : "";
    if (value)
        return value;
    value = activityPresentation && activityPresentation.icon
        ? String(activityPresentation.icon).trim() : "";
    return value || "center_focus_strong";
}

function profile(style) {
    var id = STYLES[style] ? style : "connected";
    var classic = id === "classic";
    var pill = id === "pill";
    var notch = id === "notch";
    return Object.freeze({
        id: id,
        anchor: "top-center",
        compact: Object.freeze({ inset: classic ? 8 : 4, minWidth: 160,
            maxWidth: 480, height: classic ? 36 : 32, radius: notch ? 8 : 16 }),
        banner: Object.freeze({ width: 480, height: 72, radius: notch ? 12 : 22 }),
        expanded: Object.freeze({ minWidth: 320, maxWidth: 720, height: 440,
            radius: notch ? 16 : 28 }),
        transitions: Object.freeze({ open: pill ? "fade" : "morph",
            close: pill ? "fade" : "morph", contextChange: "crossfade" }),
        capabilities: Object.freeze({ secondaryContext: !pill, dragToExpand: !classic,
            navigationRail: !pill, outsideDismiss: true })
    });
}

function geometry(profileValue, availableGeometry, mode) {
    var availableWidth = Math.max(0, Number(availableGeometry && availableGeometry.width) || 0);
    var availableHeight = Math.max(0, Number(availableGeometry && availableGeometry.height) || 0);
    var selected = mode === "expanded" ? profileValue.expanded
        : (mode === "banner" ? profileValue.banner : profileValue.compact);
    var usableWidth = mode === "expanded" ? Math.max(0, availableWidth - 40) : availableWidth;
    var naturalWidth = mode === "expanded" ? selected.maxWidth
        : (selected.width || selected.minWidth);
    var minWidth = selected.minWidth || naturalWidth;
    var width = Math.max(Math.min(minWidth, usableWidth),
        Math.min(naturalWidth, usableWidth));
    return Object.freeze({
        x: Math.max(0, (availableWidth - width) / 2), y: selected.inset || 0,
        width: width, height: Math.min(selected.height, availableHeight), radius: selected.radius
    });
}

function contextTransition(profileValue, reducedMotion) {
    var crossfade = profileValue && profileValue.transitions
        && profileValue.transitions.contextChange === "crossfade";
    if (reducedMotion === true || !crossfade)
        return Object.freeze({ kind: "replace", exitMs: 0, enterMs: 0 });
    return Object.freeze({ kind: "crossfade", exitMs: 80, enterMs: 120 });
}

function normalizedBounds(bounds) {
    var value = bounds && typeof bounds === "object" ? bounds : {};
    var x = Number(value.x);
    var y = Number(value.y);
    var width = Number(value.width);
    var height = Number(value.height);
    return Object.freeze({
        x: Number.isFinite(x) ? x : 0,
        y: Number.isFinite(y) ? y : 0,
        width: Number.isFinite(width) ? Math.max(0, width) : 0,
        height: Number.isFinite(height) ? Math.max(0, height) : 0,
    });
}

function combinedVisualBounds(primary, secondary, secondaryVisible) {
    var primaryBounds = normalizedBounds(primary);
    if (secondaryVisible !== true)
        return primaryBounds;
    var secondaryBounds = normalizedBounds(secondary);
    if (secondaryBounds.width <= 0 || secondaryBounds.height <= 0)
        return primaryBounds;
    var left = Math.min(primaryBounds.x, secondaryBounds.x);
    var top = Math.min(primaryBounds.y, secondaryBounds.y);
    var right = Math.max(primaryBounds.x + primaryBounds.width,
        secondaryBounds.x + secondaryBounds.width);
    var bottom = Math.max(primaryBounds.y + primaryBounds.height,
        secondaryBounds.y + secondaryBounds.height);
    return Object.freeze({
        x: left,
        y: top,
        width: right - left,
        height: bottom - top,
    });
}

function secondaryIndicatorTransition(previous, indicator) {
    var previousValue = previous && typeof previous === "object" ? previous : {};
    var nextValue = indicator && typeof indicator === "object" ? indicator : {};
    var previousCount = Number.isInteger(previousValue.count) && previousValue.count >= 0
        ? previousValue.count : 0;
    var previousRevision = Number.isInteger(previousValue.revision)
        && previousValue.revision >= 0 ? previousValue.revision : 0;
    var nextCount = nextValue.active === true && Number.isInteger(nextValue.count)
        && nextValue.count >= 0 ? nextValue.count : 0;
    var nextRevision = Number.isInteger(nextValue.revision) && nextValue.revision >= 0
        ? nextValue.revision : previousRevision;
    if (previous && nextRevision < previousRevision)
        return Object.freeze({ observation: Object.freeze({
            count: previousCount,
            revision: previousRevision,
        }), wobble: false });
    return Object.freeze({ observation: Object.freeze({
        count: nextCount,
        revision: nextRevision,
    }), wobble: nextValue.active === true && nextCount > previousCount });
}
