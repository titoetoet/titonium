.pragma library

function occupiedWidth(appCount, iconSize, spacing) {
    const count = Number.isInteger(appCount) && appCount > 0 ? appCount : 0;
    const size = Number.isFinite(iconSize) && iconSize > 0 ? iconSize : 0;
    const gap = Number.isFinite(spacing) && spacing > 0 ? spacing : 0;
    return Math.max(40, count * size + Math.max(0, count - 1) * gap + 16);
}

function pillHeight(active) {
    return 24;
}

function slotHeight() {
    return 24;
}

function backgroundColor(index, active, mutedPalette, activeBlue) {
    if (active === true)
        return activeBlue;
    const palette = Array.isArray(mutedPalette) ? mutedPalette : [];
    if (palette.length === 0)
        return "";
    const numeric = Number.isInteger(index) ? index : 0;
    return palette[((numeric % palette.length) + palette.length) % palette.length];
}
