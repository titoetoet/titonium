.pragma library

function text(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function initialState() {
    return Object.freeze({ initialized: false, signature: "" });
}

function stateValue(initialized, signature) {
    return Object.freeze({ initialized: initialized, signature: signature });
}

function result(next, event) {
    return Object.freeze({ next: next, event: event || null });
}

function decodeWatchLine(line) {
    if (typeof line !== "string")
        return null;
    try {
        var decoded = JSON.parse(line);
        return typeof decoded === "string" ? decoded : null;
    } catch (failure) {
        return null;
    }
}

function preview(value) {
    if (value.length <= 64)
        return value;
    return value.slice(0, 63).replace(/\s+$/, "") + "…";
}

function observe(previous, rawText, titlePrefix, now) {
    var current = previous && typeof previous === "object"
        ? previous : initialState();
    var normalized = text(rawText);
    if (!normalized) {
        var emptyState = current.initialized
            ? current : stateValue(true, "");
        return result(emptyState, null);
    }
    var next = stateValue(true, normalized);
    if (!current.initialized || current.signature === normalized)
        return result(next, null);
    var createdAt = Number.isFinite(now) ? now : 0;
    var prefix = text(titlePrefix) || "Copied";
    var event = Object.freeze({
        id: "clipboard:current",
        deduplicationKey: "clipboard:current",
        source: "clipboard",
        kind: "copied",
        title: prefix + " · " + preview(normalized),
        icon: "content_copy",
        createdAt: createdAt,
    });
    return result(next, event);

}
