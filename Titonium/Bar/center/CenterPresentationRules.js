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
