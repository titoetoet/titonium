.pragma library

function record(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value)
        ? value : {};
}

function appId(value) {
    var result = typeof value === "string" ? value.trim() : "";
    return ["__proto__", "prototype", "constructor"].indexOf(result) >= 0
        ? "" : result;
}

function validOverride(value) {
    return ["follow", "quiet", "normal", "critical", "block"].indexOf(value) >= 0;
}

function currentOverride(overrides, id) {
    var value = record(overrides)[appId(id)];
    return validOverride(value) ? value : "follow";
}

function setOverride(overrides, id, value) {
    var key = appId(id);
    if (!key || !validOverride(value))
        return overrides;
    var next = Object.assign({}, record(overrides));
    next[key] = value;
    return Object.freeze(next);
}

function resetOverride(overrides, id) {
    var source = record(overrides);
    var key = appId(id);
    if (!key || !Object.prototype.hasOwnProperty.call(source, key))
        return overrides;
    var next = Object.assign({}, source);
    delete next[key];
    return Object.freeze(next);
}

function resetAll() {
    return Object.freeze({});
}

function applicationRows(applications, overrides) {
    var rows = [];
    var seen = Object.create(null);
    var source = Array.isArray(applications) ? applications : [];
    for (var index = 0; index < source.length; index++) {
        var application = record(source[index]);
        var id = appId(application.id);
        if (!id || seen[id])
            continue;
        seen[id] = true;
        rows.push(Object.freeze({
            id: id,
            name: appId(application.name) || id,
            icon: appId(application.icon),
        }));
    }
    Object.keys(record(overrides)).forEach(function(id) {
        var key = appId(id);
        if (!key || seen[key])
            return;
        seen[key] = true;
        rows.push(Object.freeze({ id: key, name: key, icon: "" }));
    });
    rows.sort(function(left, right) {
        return left.name.localeCompare(right.name);
    });
    return Object.freeze(rows);
}
