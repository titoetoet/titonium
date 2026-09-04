.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function semanticName(value, fallback) {
    const candidate = text(value);
    const safeFallback = text(fallback) || "image";
    if (!candidate || candidate.indexOf("/") >= 0
            || candidate.indexOf("://") >= 0
            || candidate.indexOf("qrc:") === 0)
        return safeFallback;
    return candidate;
}
