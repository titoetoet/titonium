.pragma library

function pad(value) {
    return String(value).padStart(2, "0");
}

function dateKey(date) {
    if (!date || typeof date.getTime !== "function" || !Number.isFinite(date.getTime()))
        return "";
    return String(date.getFullYear()) + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate());
}

function lines(value) {
    if (typeof value !== "string")
        return [];
    return value.split(/\r?\n/).map(function(line) {
        return line.trim();
    }).filter(function(line) {
        return line.length > 0;
    });
}

function explicitFocus(markdown, modifiedAt, now) {
    if (!Number.isFinite(modifiedAt) || modifiedAt <= 0 || dateKey(new Date(modifiedAt)) !== dateKey(now))
        return "";

    var candidates = lines(markdown);
    for (var index = 0; index < candidates.length; index++) {
        if (!/^#+(?:\s|$)/.test(candidates[index]))
            return candidates[index];
    }
    return "";
}

function dateHash(key) {
    var hash = 0;
    for (var index = 0; index < key.length; index++)
        hash = ((hash * 31) + key.charCodeAt(index)) >>> 0;
    return hash;
}

function deterministicFallback(prompts, now) {
    var candidates = lines(prompts);
    var key = dateKey(now);
    if (candidates.length === 0 || !key)
        return "";
    return candidates[dateHash(key) % candidates.length];
}

function select(state, now) {
    if (!state || typeof state !== "object")
        return "";
    return explicitFocus(state.markdown, state.modifiedAt, now)
        || deterministicFallback(state.prompts, now);
}
