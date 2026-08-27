.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function descriptor(raw) {
    const source = raw && typeof raw === "object" ? raw : {};
    const id = text(source.id);
    if (!id)
        return null;
    const appId = text(source.appId) || text(source.ipcClass)
        || text(source.initialClass) || text(source.title);
    const title = text(source.title) || appId || "Application";
    const workspaceId = Number.isInteger(source.workspaceId) && source.workspaceId > 0
        ? source.workspaceId : 0;
    return Object.freeze({
        id: id,
        appId: appId,
        title: title,
        icon: text(source.icon),
        active: Boolean(source.active),
        urgent: Boolean(source.urgent),
        minimized: Boolean(source.minimized),
        workspaceId: workspaceId,
        monitorName: text(source.monitorName),
    });
}

function focusPlan(id, windows) {
    const targetId = text(id);
    const source = Array.isArray(windows) ? windows : [];
    for (let index = 0; index < source.length; index++) {
        if (text(source[index]?.id) !== targetId)
            continue;
        const workspaceId = Number.isInteger(source[index]?.workspaceId)
            && source[index].workspaceId > 0 ? source[index].workspaceId : 0;
        return Object.freeze({ id: targetId, workspaceId: workspaceId });
    }
    return null;
}

function windowSelector(id) {
    let value = text(id);
    if (value.indexOf("address:") === 0)
        value = value.slice(8);
    const raw = value.indexOf("0x") === 0 ? value.slice(2) : value;
    if (!/^[0-9a-fA-F]+$/.test(raw))
        return "";
    return "address:" + (value.indexOf("0x") === 0 ? value : "0x" + value);
}

function focusCommand(id, usingLua) {
    const selector = windowSelector(id);
    if (!selector)
        return "";
    return usingLua
        ? "hl.dsp.focus({ window = \"" + selector + "\" })"
        : "focuswindow " + selector;
}

function mruIds(previousIds, windows) {
    const previous = Array.isArray(previousIds) ? previousIds : [];
    const source = Array.isArray(windows) ? windows : [];
    const live = {};
    const result = [];
    const seen = {};

    for (let index = 0; index < source.length; index++) {
        const id = text(source[index]?.id);
        if (id)
            live[id] = true;
    }

    function append(id) {
        const value = text(id);
        if (!value || !live[value] || seen[value])
            return;
        seen[value] = true;
        result.push(value);
    }

    for (let index = 0; index < source.length; index++) {
        if (source[index]?.active === true)
            append(source[index].id);
    }
    for (let index = 0; index < previous.length; index++)
        append(previous[index]);
    for (let index = 0; index < source.length; index++)
        append(source[index]?.id);
    return Object.freeze(result);
}

function orderByIds(windows, orderedIds) {
    const source = Array.isArray(windows) ? windows : [];
    const order = Array.isArray(orderedIds) ? orderedIds : [];
    const byId = {};
    const emitted = {};
    const result = [];
    for (let index = 0; index < source.length; index++) {
        const id = text(source[index]?.id);
        if (id && !byId[id])
            byId[id] = source[index];
    }
    for (let index = 0; index < order.length; index++) {
        const id = text(order[index]);
        if (!id || emitted[id] || !byId[id])
            continue;
        emitted[id] = true;
        result.push(byId[id]);
    }
    for (let index = 0; index < source.length; index++) {
        const id = text(source[index]?.id);
        if (!id || emitted[id])
            continue;
        emitted[id] = true;
        result.push(source[index]);
    }
    return Object.freeze(result);
}
