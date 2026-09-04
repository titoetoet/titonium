.pragma library

function normalizeStyle(style) {
    return style === "classic" ? "classic" : "connected";
}

function profile(style, screenWidth, screenHeight) {
    const normalized = normalizeStyle(style);
    return Object.freeze({
        style: normalized,
        compactY: normalized === "classic" ? 4 : 0,
        surfaceTone: normalized === "classic" ? "elevated" : "connected",
        horizontalPadding: normalized === "classic" ? 12 : 0
    });
}
