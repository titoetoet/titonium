.pragma library
// Protected Spotlight vertical slice.

var orderedScopes = ["applications", "clipboard", "system"];

function normalize(scope) {
    return orderedScopes.indexOf(scope) >= 0 ? scope : "applications";
}

function next(scope, delta) {
    const currentIndex = orderedScopes.indexOf(normalize(scope));
    const direction = Number(delta) < 0 ? -1 : 1;
    return orderedScopes[(currentIndex + direction + orderedScopes.length) % orderedScopes.length];
}

function modeFor(scope, query) {
    const normalized = normalize(scope);
    if (normalized !== "applications")
        return normalized;
    return typeof query === "string" && query.trim().length > 0 ? "results" : "browse";
}
