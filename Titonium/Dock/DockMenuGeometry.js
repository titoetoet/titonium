.pragma library

// Dock bounds are in the full-screen OverlayHost's logical coordinate space.
function panelRect(viewportWidth, viewportHeight, dockBounds, anchorX,
        contentWidth, contentHeight, connected) {
    const margin = connected ? 24 : 8;
    const width = Math.max(0, Math.min(contentWidth, viewportWidth - margin * 2));
    const dockTop = dockBounds && dockBounds.y > 0
        ? dockBounds.y : Math.max(0, viewportHeight - 64);
    // Keep the detached popup above the Dock hitbox in both styles.
    const bottom = Math.max(8, dockTop - 8);
    const height = Math.max(0, Math.min(contentHeight, bottom - 8));
    const center = Number.isFinite(anchorX) ? anchorX : viewportWidth / 2;
    return { x: Math.max(margin, Math.min(viewportWidth - margin - width, center - width / 2)),
        y: bottom - height, width: width, height: height };
}
