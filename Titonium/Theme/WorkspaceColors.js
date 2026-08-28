.pragma library

function workspaceColor(workspaceId, palette, fallback) {
    const id = Number(workspaceId);
    const colors = Array.isArray(palette) ? palette : [];
    if (!Number.isInteger(id) || id < 1 || colors.length === 0)
        return fallback;
    return colors[(id - 1) % colors.length] || fallback;
}

function tileColor(workspaceId, selected, hovered, palette, idle) {
    if (selected !== true && hovered !== true)
        return idle;
    return workspaceColor(workspaceId, palette, idle);
}
