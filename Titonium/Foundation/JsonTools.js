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

