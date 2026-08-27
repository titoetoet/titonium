.pragma library

function categoryNames(values) {
    if (!values)
        return [];
    const length = Math.max(0, Math.floor(Number(values.length) || 0));
    const result = [];
    for (let index = 0; index < length; index++) {
        const value = String(values[index] || "").trim();
        if (value.length > 0)
            result.push(value);
    }
    return result;
}
