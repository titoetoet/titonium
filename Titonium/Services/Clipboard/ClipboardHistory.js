.pragma library

var MAX_ITEMS = 60;
var PREVIEW_LENGTH = 80;
var VALID_KINDS = ["url", "color", "code", "plain", "image"];

function preview(text) {
    if (typeof text !== "string") return "";
    var line = text.replace(/\s+/g, " ").trim();
    return line.length <= PREVIEW_LENGTH ? line : line.slice(0, PREVIEW_LENGTH - 1) + "…";
}

function classify(text) {
    var trimmed = typeof text === "string" ? text.trim() : "";
    if (/^https?:\/\/[^\s]+$/i.test(trimmed)) return { kind: "url", colorHex: "" };
    if (/^#(?:[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(trimmed))
        return { kind: "color", colorHex: trimmed };
    if (/\b(function|class|const|let|var|return|import|export|def|fn|SELECT|INSERT|UPDATE|DELETE)\b|=>|[{};]\s*(?:\n|$)/m.test(text || ""))
        return { kind: "code", colorHex: "" };
    return { kind: "plain", colorHex: "" };
}

function isFiniteNumber(value) { return typeof value === "number" && isFinite(value); }
function isRecord(item) {
    return item !== null && typeof item === "object" && typeof item.id === "string"
        && item.id.length > 0 && typeof item.text === "string" && item.text.length > 0
        && typeof item.preview === "string" && VALID_KINDS.indexOf(item.kind) >= 0
        && typeof item.colorHex === "string" && isFiniteNumber(item.timestamp)
        && isFiniteNumber(item.lines) && item.lines >= 1 && isFiniteNumber(item.words)
        && item.words >= 0 && isFiniteNumber(item.chars) && item.chars >= 1;
}
function isDocument(document) {
    return document !== null && typeof document === "object"
        && document.schemaVersion === 1 && Array.isArray(document.items);
}
function normalizeDocument(document) {
    if (!isDocument(document)) return [];
    var normalized = [], seen = {};
    for (var index = 0; index < document.items.length && normalized.length < MAX_ITEMS; index++) {
        var item = document.items[index];
        var key = "$text:" + (item && typeof item.text === "string" ? item.text : "");
        if (!isRecord(item) || seen[key] === true) continue;
        seen[key] = true;
        normalized.push({ id: item.id, text: item.text, preview: item.preview, kind: item.kind,
            colorHex: item.colorHex, timestamp: item.timestamp, lines: item.lines,
            words: item.words, chars: item.chars,
            imagePath: typeof item.imagePath === "string" ? item.imagePath : "",
            imageWidth: typeof item.imageWidth === "number" ? item.imageWidth : 0,
            imageHeight: typeof item.imageHeight === "number" ? item.imageHeight : 0,
            bytes: typeof item.bytes === "number" ? item.bytes : 0,
            md5: typeof item.md5 === "string" ? item.md5 : "",
            sourceApp: typeof item.sourceApp === "string" ? item.sourceApp : "",
            sourceTitle: typeof item.sourceTitle === "string" ? item.sourceTitle : "" });
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
function createRecord(text, timestamp, sourceApp, sourceTitle) {
    var type = classify(text), trimmed = text.trim();
    return { id: "clipboard-" + timestamp + "-" + stableHash(text), text: text,
        preview: preview(text), kind: type.kind, colorHex: type.colorHex, timestamp: timestamp,
        lines: text.split(/\r\n|\r|\n/).length,
        words: trimmed.length === 0 ? 0 : trimmed.split(/\s+/).length, chars: text.length,
        imagePath: "", imageWidth: 0, imageHeight: 0, bytes: text.length, md5: "",
        sourceApp: typeof sourceApp === "string" ? sourceApp : "",
        sourceTitle: typeof sourceTitle === "string" ? sourceTitle : "" };
}
function createImageRecord(imagePath, width, height, bytes, md5, timestamp, sourceApp, sourceTitle) {
    var desc = "Image (" + width + "x" + height + ")";
    var recordId = "clipboard-" + timestamp + "-" + (md5 || stableHash(imagePath || desc));
    return { id: recordId, text: desc, preview: desc, kind: "image", colorHex: "",
        timestamp: timestamp, lines: 1, words: 1, chars: desc.length,
        imagePath: imagePath || "", imageWidth: width || 0, imageHeight: height || 0,
        bytes: bytes || 0, md5: md5 || "",
        sourceApp: typeof sourceApp === "string" ? sourceApp : "",
        sourceTitle: typeof sourceTitle === "string" ? sourceTitle : "" };
}
function recordImage(items, imagePath, width, height, bytes, md5, timestamp, sourceApp, sourceTitle) {
    var source = Array.isArray(items) ? items : [];
    if (typeof imagePath !== "string" || imagePath.length === 0) return source.slice(0, MAX_ITEMS);
    var observedAt = isFiniteNumber(timestamp) ? timestamp : Date.now(), next = [], existing = null;
    for (var index = 0; index < source.length; index++) {
        if (source[index].kind === "image" && (source[index].md5 === md5 || source[index].imagePath === imagePath))
            existing = source[index];
        else
            next.push(source[index]);
    }
    var newest = existing === null ? createImageRecord(imagePath, width, height, bytes, md5, observedAt, sourceApp, sourceTitle) : {
        id: existing.id, text: existing.text, preview: existing.preview, kind: "image",
        colorHex: "", timestamp: observedAt, lines: existing.lines, words: existing.words,
        chars: existing.chars, imagePath: imagePath, imageWidth: width, imageHeight: height,
        bytes: bytes, md5: md5,
        sourceApp: typeof sourceApp === "string" ? sourceApp : (existing.sourceApp || ""),
        sourceTitle: typeof sourceTitle === "string" ? sourceTitle : (existing.sourceTitle || "")
    };
    next.unshift(newest);
    return next.slice(0, MAX_ITEMS);
}
function record(items, text, timestamp, sourceApp, sourceTitle) {
    var source = Array.isArray(items) ? items : [];
    if (typeof text !== "string" || text.length === 0) return source.slice(0, MAX_ITEMS);
    var observedAt = isFiniteNumber(timestamp) ? timestamp : Date.now(), next = [], existing = null;
    for (var index = 0; index < source.length; index++) {
        if (source[index].text === text && existing === null) existing = source[index];
        else next.push(source[index]);
    }
    var newest = existing === null ? createRecord(text, observedAt, sourceApp, sourceTitle) : {
        id: existing.id, text: existing.text, preview: existing.preview, kind: existing.kind,
        colorHex: existing.colorHex, timestamp: observedAt, lines: existing.lines,
        words: existing.words, chars: existing.chars,
        imagePath: existing.imagePath || "", imageWidth: existing.imageWidth || 0,
        imageHeight: existing.imageHeight || 0, bytes: existing.bytes || existing.text.length,
        md5: existing.md5 || "",
        sourceApp: typeof sourceApp === "string" ? sourceApp : (existing.sourceApp || ""),
        sourceTitle: typeof sourceTitle === "string" ? sourceTitle : (existing.sourceTitle || "") };
    next.unshift(newest);
    return next.slice(0, MAX_ITEMS);
}
function remove(items, id) {
    if (!Array.isArray(items) || typeof id !== "string") return [];
    return items.filter(function(item) { return item.id !== id; });
}
function itemForId(items, id) {
    if (!Array.isArray(items) || typeof id !== "string") return null;
    for (var index = 0; index < items.length; index++) if (items[index].id === id) return items[index];
    return null;
}
