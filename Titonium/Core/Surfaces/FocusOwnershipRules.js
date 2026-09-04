.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function snapshot(owner, acquiredAt, releasedAt, violation, lease) {
    const result = {
        owner: text(owner), acquiredAt: Math.max(0, Number(acquiredAt) || 0),
        releasedAt: Math.max(0, Number(releasedAt) || 0), violation: text(violation),
    };
    Object.defineProperty(result, "lease", {
        value: text(lease), enumerable: false, writable: false, configurable: false,
    });
    return Object.freeze(result);
}

function initial() {
    return snapshot("", 0, 0, "");
}

function transition(current, ownerId, active, now, lease) {
    const state = current && typeof current === "object" ? current : initial();
    const owner = text(ownerId);
    const timestamp = Math.max(0, Number(now) || 0);
    const leaseAware = arguments.length >= 5;
    const requesterLease = text(lease);
    if (!owner)
        return snapshot(state.owner, state.acquiredAt, state.releasedAt,
            "missing-focus-owner", state.lease);
    if (leaseAware && !requesterLease)
        return snapshot(state.owner, state.acquiredAt, state.releasedAt,
            "missing-focus-lease", state.lease);
    if (active === true) {
        if (state.owner && state.owner !== owner)
            return snapshot(state.owner, state.acquiredAt, state.releasedAt,
                "exclusive-focus-conflict:" + state.owner + ":" + owner, state.lease);
        if (leaseAware && state.owner === owner && state.lease
                && state.lease !== requesterLease)
            return snapshot(state.owner, state.acquiredAt, state.releasedAt,
                "exclusive-focus-conflict:" + state.owner + ":" + owner, state.lease);
        return snapshot(owner, state.owner === owner ? state.acquiredAt : timestamp,
            state.releasedAt, "", leaseAware ? requesterLease : state.lease);
    }
    if (state.owner !== owner)
        return snapshot(state.owner, state.acquiredAt, state.releasedAt, "", state.lease);
    if (leaseAware && state.lease && state.lease !== requesterLease)
        return state;
    return snapshot("", 0, timestamp, "", "");
}
