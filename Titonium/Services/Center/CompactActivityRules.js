.pragma library

// Compact ownership never depends on which activity is open in Normal.
function eligible(contexts) {
    return (contexts || []).filter(function(item) {
        return ["capture", "focus", "media"].indexOf(item.source) >= 0
            && item.kind !== "screenshot"
            && !(item.source === "focus" && item.kind === "daily")
            && !(item.source === "media" && item.details?.playbackState === "stopped");
    });
}
function rank(item) {
    return item?.source === "focus" ? 400 : item?.source === "capture" ? 300
        : item?.source === "media" ? 100 : 0;
}
function reconcile(previous, contexts) {
    var values = eligible(contexts);
    var order = previous?.order || [];
    values.sort(function(a, b) {
        var difference = rank(b) - rank(a);
        if (difference) return difference;
        var ai = order.indexOf(a.id), bi = order.indexOf(b.id);
        if (ai >= 0 || bi >= 0) return (ai < 0 ? 999999 : ai) - (bi < 0 ? 999999 : bi);
        return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
    });
    return Object.freeze({ idle: values.length === 0,
        primaryId: values[0]?.id || "", secondaryId: values[1]?.id || "",
        order: Object.freeze(values.map(function(item) { return item.id; })) });
}
