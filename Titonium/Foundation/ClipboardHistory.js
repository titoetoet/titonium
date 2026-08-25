.pragma library

var MAX_ITEMS = 60;
var PREVIEW_LENGTH = 80;
var VALID_KINDS = ["url", "color", "code", "plain"];

function preview(text) {
    if (typeof text !== "string")
        return "";
    var singleLine = text.replace(/\s+/g, " ").trim();
    if (singleLine.length <= PREVIEW_LENGTH)
        return singleLine;
    return singleLine.slice(0, PREVIEW_LENGTH - 1) + "…";
}

function classify(text) {
    var trimmed = typeof text === "string" ? text.trim() : "";
    if (/^https?:\/\/[^\s]+$/i.test(trimmed))
        return { kind: "url", colorHex: "" };
    if (/^#(?:[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(trimmed))
        return { kind: "color", colorHex: trimmed };
    if (/\b(function|class|const|let|var|return|import|export|def|fn|SELECT|INSERT|UPDATE|DELETE)\b|=>|[{};]\s*(?:\n|$)/m.test(text || ""))
        return { kind: "code", colorHex: "" };
    return { kind: "plain", colorHex: "" };
}

function isFiniteNumber(value) {
    return typeof value === "number" && isFinite(value);
}

function isRecord(item) {
    return item !== null && typeof item === "object"
        && typeof item.id === "string" && item.id.length > 0
        && typeof item.text === "string" && item.text.length > 0
        && typeof item.preview === "string"
        && VALID_KINDS.indexOf(item.kind) >= 0
        && typeof item.colorHex === "string"
        && isFiniteNumber(item.timestamp)
        && isFiniteNumber(item.lines) && item.lines >= 1
        && isFiniteNumber(item.words) && item.words >= 0
        && isFiniteNumber(item.chars) && item.chars >= 1;
}

function isDocument(document) {
    return document !== null && typeof document === "object"
        && document.schemaVersion === 1 && Array.isArray(document.items);
}

function normalizeDocument(document) {
    if (!isDocument(document))
        return [];
    var normalized = [];
    var seen = {};
    for (var index = 0; index < document.items.length && normalized.length < MAX_ITEMS; index++) {
        var item = document.items[index];
        var dedupeKey = "$text:" + (item && typeof item.text === "string" ? item.text : "");
        if (!isRecord(item) || seen[dedupeKey] === true)
            continue;
        seen[dedupeKey] = true;
        normalized.push({
            id: item.id,
            text: item.text,
            preview: item.preview,
            kind: item.kind,
            colorHex: item.colorHex,
            timestamp: item.timestamp,
            lines: item.lines,
            words: item.words,
            chars: item.chars
        });
    }
    return normalized;
}

function stableHash(text) {
    var hash = 2166136261;
    for (var index = 0; index < text.length; index++) {
        hash ^= text.charCodeAt(index);
        hash = Math.imul(hash, 16777619);
    }
    return (hash >>> 0).toString(36);
}

function createRecord(text, timestamp) {
    var classification = classify(text);
    var trimmed = text.trim();
    return {
        id: "clipboard-" + timestamp + "-" + stableHash(text),
        text: text,
        preview: preview(text),
        kind: classification.kind,
        colorHex: classification.colorHex,
        timestamp: timestamp,
        lines: text.split(/\r\n|\r|\n/).length,
        words: trimmed.length === 0 ? 0 : trimmed.split(/\s+/).length,
        chars: text.length
    };
}

function record(items, text, timestamp) {
    var source = Array.isArray(items) ? items : [];
    if (typeof text !== "string" || text.length === 0)
        return source.slice(0, MAX_ITEMS);
    var observedAt = isFiniteNumber(timestamp) ? timestamp : Date.now();
    var next = [];
    var existing = null;
    for (var index = 0; index < source.length; index++) {
        if (source[index].text === text && existing === null)
            existing = source[index];
        else
            next.push(source[index]);
    }
    var newest = existing === null ? createRecord(text, observedAt) : {
        id: existing.id,
        text: existing.text,
        preview: existing.preview,
        kind: existing.kind,
        colorHex: existing.colorHex,
        timestamp: observedAt,
        lines: existing.lines,
        words: existing.words,
        chars: existing.chars
    };
    next.unshift(newest);
    return next.slice(0, MAX_ITEMS);
}

function remove(items, id) {
    if (!Array.isArray(items) || typeof id !== "string")
        return [];
    return items.filter(function(item) { return item.id !== id; });
}

function itemForId(items, id) {
    if (!Array.isArray(items) || typeof id !== "string")
        return null;
    for (var index = 0; index < items.length; index++) {
        if (items[index].id === id)
            return items[index];
    }
    return null;
}
