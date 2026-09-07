.pragma library

function finite(value, fallback) {
    const number = Number(value);
    return Number.isFinite(number) ? number : fallback;
}

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
}

function branchRect(edge, sourceX, sourceWidth, compactWidth, outputWidth,
                    menuWidth, menuHeight, progress) {
    const output = Math.max(32, finite(outputWidth, 32));
    const requestedWidth = Math.max(120, finite(menuWidth, 420));
    const sourceW = Math.max(1, finite(sourceWidth, 1));
    const source = finite(sourceX, 12);
    // Two opposing 16px shoulders plus 16px of clear space between them.
    // Keep this gutter consistent across source controls and popup widths.
    const inset = Math.min(48, (output - 1) / 2);
    const sourceCenter = clamp(source + sourceW / 2, inset, output - inset);
    const targetWidth = Math.max(1, Math.min(requestedWidth, output - inset * 2));
    const p = clamp(finite(progress, 0), 0, 1);
    const targetX = edge === "right" ? output - inset - targetWidth
        : clamp(sourceCenter - targetWidth / 2, inset, output - inset - targetWidth);
    const width = sourceW + (targetWidth - sourceW) * p;
    const x = source + (targetX - source) * p;
    const targetBottom = Math.max(36, finite(menuHeight, 120));
    return Object.freeze({
        x: x,
        y: 28,
        width: width,
        height: 8 + (targetBottom - 36) * p
    });
}

function chassisRect(edge, compactWidth, outputWidth, branch) {
    const output = Math.max(32, finite(outputWidth, 32));
    const compact = Math.max(1, finite(compactWidth, 1));
    const pillX = edge === "right" ? output - compact : 0;
    const left = Math.min(pillX, branch.x);
    const right = Math.max(pillX + compact, branch.x + branch.width);
    return Object.freeze({x: left, width: right - left});
}

function anchorSnapshot(edge, screenName, x, y, width, height) {
    return Object.freeze({
        edge: edge === "right" ? "right" : "left",
        screenName: String(screenName || ""),
        x: finite(x, 0),
        y: finite(y, 0),
        width: Math.max(1, finite(width, 1)),
        height: Math.max(1, finite(height, 1))
    });
}

function detachedPopupX(anchor, screenName, outputWidth, popupWidth, margin) {
    const inset = Math.max(0, finite(margin, 12));
    const output = Math.max(inset * 2 + 1, finite(outputWidth, inset * 2 + 1));
    const width = Math.max(1, Math.min(finite(popupWidth, 380), output - inset * 2));
    if (!anchor || anchor.screenName !== String(screenName || ""))
        return Math.max(inset, output - inset - width);
    const center = finite(anchor.x, inset) + Math.max(1, finite(anchor.width, 1)) / 2;
    return clamp(center - width / 2, inset, output - inset - width);
}
