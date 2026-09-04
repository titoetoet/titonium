.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function snapshot(owner, acquiredAt, releasedAt, violation) {
    return Object.freeze({ owner: text(owner), acquiredAt: Math.max(0, Number(acquiredAt) || 0),
        releasedAt: Math.max(0, Number(releasedAt) || 0), violation: text(violation) });
}

function initial() {
    return snapshot("", 0, 0, "");
}

function transition(current, ownerId, active, now) {
    const state = current && typeof current === "object" ? current : initial();
    const owner = text(ownerId);
    const timestamp = Math.max(0, Number(now) || 0);
    if (!owner)
        return snapshot(state.owner, state.acquiredAt, state.releasedAt, "missing-focus-owner");
    if (active === true) {
        if (state.owner && state.owner !== owner)
            return snapshot(state.owner, state.acquiredAt, state.releasedAt,
                "exclusive-focus-conflict:" + state.owner + ":" + owner);
        return snapshot(owner, state.owner === owner ? state.acquiredAt : timestamp,
            state.releasedAt, "");
    }
    if (state.owner !== owner)
        return snapshot(state.owner, state.acquiredAt, state.releasedAt, "");
    return snapshot("", 0, timestamp, "");
}
