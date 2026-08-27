.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function visibleWindows(windows) {
    const source = Array.isArray(windows) ? windows : [];
    const seen = {};
    const result = [];
    for (let index = 0; index < source.length; index++) {
        const window = source[index];
        const id = text(window?.id);
        if (!id || seen[id] || window?.minimized === true)
            continue;
        seen[id] = true;
        result.push(window);
    }
    return result;
}

function mruIds(previousIds, windows) {
    const visible = visibleWindows(windows);
    const previous = Array.isArray(previousIds) ? previousIds : [];
    const live = {};
    const emitted = {};
    const result = [];
    for (let index = 0; index < visible.length; index++)
        live[visible[index].id] = true;

    function append(id) {
        const value = text(id);
        if (!value || !live[value] || emitted[value])
            return;
        emitted[value] = true;
        result.push(value);
    }

    for (let index = 0; index < visible.length; index++) {
        if (visible[index]?.active === true)
            append(visible[index].id);
    }
    for (let index = 0; index < previous.length; index++)
        append(previous[index]);
    for (let index = 0; index < visible.length; index++)
        append(visible[index].id);
    return Object.freeze(result);
}

function orderedWindows(windows, orderedIds) {
    const visible = visibleWindows(windows);
    const order = Array.isArray(orderedIds) ? orderedIds : [];
    const byId = {};
    const emitted = {};
    const result = [];
    for (let index = 0; index < visible.length; index++)
        byId[visible[index].id] = visible[index];
    for (let index = 0; index < order.length; index++) {
        const id = text(order[index]);
        if (!id || emitted[id] || !byId[id])
            continue;
        emitted[id] = true;
        result.push(byId[id]);
    }
    for (let index = 0; index < visible.length; index++) {
        const id = visible[index].id;
        if (emitted[id])
            continue;
        emitted[id] = true;
        result.push(visible[index]);
    }
    return Object.freeze(result);
}

function indexForId(windows, id) {
    const source = Array.isArray(windows) ? windows : [];
    const target = text(id);
    for (let index = 0; index < source.length; index++) {
        if (text(source[index]?.id) === target)
            return index;
    }
    return -1;
}

function reconcileSelection(windows, selectedId) {
    const source = Array.isArray(windows) ? windows : [];
    if (source.length === 0)
        return "";
    const selectedIndex = indexForId(source, selectedId);
    return selectedIndex >= 0 ? source[selectedIndex].id : text(source[0]?.id);
}

function moveSelection(windows, selectedId, offset) {
    const source = Array.isArray(windows) ? windows : [];
    if (source.length === 0)
        return "";
    const selectedIndex = indexForId(source, selectedId);
    const start = selectedIndex >= 0 ? selectedIndex : 0;
    const step = Number(offset) < 0 ? -1 : 1;
    return text(source[(start + step + source.length) % source.length]?.id);
}

function beginSelection(windows, direction) {
    const source = Array.isArray(windows) ? windows : [];
    if (source.length === 0)
        return "";
    return moveSelection(source, text(source[0]?.id), direction === "previous" ? -1 : 1);
}
