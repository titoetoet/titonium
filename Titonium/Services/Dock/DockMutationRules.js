.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function unique(values) {
    const source = Array.isArray(values) ? values : [];
    const seen = {};
    const result = [];
    for (let index = 0; index < source.length; index++) {
        const value = text(source[index]);
        const key = value.toLocaleLowerCase();
        if (!value || seen[key])
            continue;
        seen[key] = true;
        result.push(value);
    }
    return result;
}

function result(accepted, persisted, value, error) {
    const frozenValue = Array.isArray(value) ? Object.freeze(unique(value)) : value;
    return Object.freeze({ accepted: accepted === true, persisted: persisted === true,
        value: frozenValue, error: text(error) });
}

function toggle(current, appId) {
    const id = text(appId);
    const values = unique(current);
    if (!id)
        return result(false, false, values, "invalid-app-id");
    const key = id.toLocaleLowerCase();
    const index = values.findIndex(value => value.toLocaleLowerCase() === key);
    if (index >= 0)
        values.splice(index, 1);
    else
        values.push(id);
    return result(true, false, values, "");
}

function withWriteResult(plan, writeAccepted, error) {
    if (!plan || plan.accepted !== true)
        return result(false, false, plan && plan.value, plan && plan.error || error);
    return writeAccepted === true
        ? result(true, true, plan.value, "")
        : result(false, false, plan.value, error || "write-rejected");
}

function visibility(value, writeAccepted, error) {
    return result(writeAccepted === true, writeAccepted === true, value === true,
        writeAccepted === true ? "" : (error || "write-rejected"));
}
