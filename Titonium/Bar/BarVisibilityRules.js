.pragma library

function shouldReveal(pinned, edgeHovered, barHovered, hoverSuppressed) {
    return Boolean(pinned) || (!hoverSuppressed && (Boolean(edgeHovered) || Boolean(barHovered)));
}

function exclusiveZone(pinned, barHeight) {
    const height = Number(barHeight);
    return Boolean(pinned) && Number.isFinite(height) && height > 0 ? height : 0;
}

// Only a revealed auto-hide bar bridges the spaces between islands.
function revealRegionHeight(pinned, revealed, barHeight, edgeHeight) {
    return !pinned && revealed ? barHeight : edgeHeight;
}
