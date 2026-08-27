.pragma library

function shouldReveal(pinned, edgeHovered, barHovered) {
    return Boolean(pinned) || Boolean(edgeHovered) || Boolean(barHovered);
}

function exclusiveZone(pinned, barHeight) {
    const height = Number(barHeight);
    return Boolean(pinned) && Number.isFinite(height) && height > 0 ? height : 0;
}
