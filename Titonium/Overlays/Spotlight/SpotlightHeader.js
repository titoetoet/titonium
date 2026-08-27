.pragma library
// Presentation descriptors for the protected Spotlight header.

var actions = Object.freeze([
    Object.freeze({
        "id": "applications",
        "icon": "apps",
        "accessibleKey": "spotlight.scope.applications"
    }),
    Object.freeze({
        "id": "clipboard",
        "icon": "content_paste",
        "accessibleKey": "spotlight.scope.clipboard"
    }),
    Object.freeze({
        "id": "system",
        "icon": "manage_search",
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
    return 620;
}

function searchFieldHeight() {
    return 48;
}

function scopeButtonSize() {
    return 48;
}

function scopeStripWidth(spacing) {
    return actions.length * scopeButtonSize()
        + Math.max(0, actions.length - 1) * Math.max(0, Number(spacing) || 0);
}
