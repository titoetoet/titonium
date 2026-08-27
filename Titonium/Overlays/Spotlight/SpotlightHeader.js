.pragma library
// Presentation descriptors for the protected Spotlight header.

var actions = Object.freeze([
    Object.freeze({
        "id": "applications",
        "icon": "apps",
        "iconSize": 20,
        "accessibleKey": "spotlight.scope.applications"
    }),
    Object.freeze({
        "id": "clipboard",
        "icon": "content_paste",
        "iconSize": 19,
        "accessibleKey": "spotlight.scope.clipboard"
    }),
    Object.freeze({
        "id": "system",
        "icon": "manage_search",
        "iconSize": 20,
        "accessibleKey": "spotlight.scope.system"
    })
]);

function scopeActions() {
    return actions;
}

function identityIconSize() {
    return 28;
}

function searchFieldWidth() {
    return 560;
}

function searchFieldHeight() {
    return 46;
}

function scopeButtonSize() {
    return 44;
}

function scopeStripWidth(spacing) {
    return actions.length * scopeButtonSize()
        + Math.max(0, actions.length - 1) * Math.max(0, Number(spacing) || 0);
}

function scopeGroupWidth() {
    return 200;
}
