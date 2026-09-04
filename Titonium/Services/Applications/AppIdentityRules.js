.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function candidates(identity) {
    const source = identity && typeof identity === "object" ? identity : {};
    const values = [source.appId, source.ipcClass, source.initialClass];
    const title = text(source.title);
    if (title && title.indexOf(" ") < 0)
        values.push(title);
    const seen = {};
    const result = [];
    for (let index = 0; index < values.length; index++) {
        const value = text(values[index]);
        const key = value.toLocaleLowerCase();
        if (!value || seen[key])
            continue;
        seen[key] = true;
        result.push(value);
        if (key.indexOf(".") >= 0) {
            const tail = key.split(".").pop();
            if (tail && !seen[tail]) {
                seen[tail] = true;
                result.push(tail);
            }
        }
    }
    return result;
}

function fallbackFor(appId, desktopEntryId) {
    const identity = (text(appId) + " " + text(desktopEntryId)).toLocaleLowerCase();
    return identity.indexOf("chatgpt") >= 0 ? "smart_toy" : "apps";
}

function resolve(identity, lookupEntry, resolveIcon) {
    const values = candidates(identity);
    let entry = null;
    let appId = values.length > 0 ? values[0] : "";
    for (let index = 0; index < values.length; index++) {
        entry = lookupEntry(values[index]);
        if (entry) {
            appId = values[index];
            break;
        }
    }
    const desktopEntryId = text(entry && entry.id);
    const icon = entry && entry.icon ? text(resolveIcon(entry.icon)) : "";
    return Object.freeze({
        appId: appId,
        desktopEntryId: desktopEntryId,
        icon: icon,
        fallbackIcon: fallbackFor(appId, desktopEntryId)
    });
}
