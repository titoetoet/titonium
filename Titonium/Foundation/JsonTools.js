.pragma library

function clone(value) {
    if (value === undefined || value === null)
        return value;
    return JSON.parse(JSON.stringify(value));
}

function parse(text, fallback) {
    if (!text || text.trim().length === 0)
        return fallback;
    try {
        return JSON.parse(text);
    } catch (error) {
        return fallback;
    }
}

function setPath(source, path, value) {
    const result = clone(source);
    const parts = path.split(".").filter(part => part.length > 0);
    if (parts.length === 0)
        return result;

    let cursor = result;
    for (let index = 0; index < parts.length - 1; index++) {
        const part = parts[index];
        if (!cursor[part] || typeof cursor[part] !== "object")
            cursor[part] = {};
        cursor = cursor[part];
    }
    cursor[parts[parts.length - 1]] = value;
    return result;
}

function mergeDeep(base, override) {
    const result = clone(base) || {};
    if (!override || typeof override !== "object" || Array.isArray(override))
        return result;
    Object.keys(override).forEach(key => {
        const value = override[key];
        if (value && typeof value === "object" && !Array.isArray(value))
            result[key] = mergeDeep(result[key] || {}, value);
        else
            result[key] = clone(value);
    });
    return result;
}
