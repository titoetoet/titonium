.pragma library

function normalizeOwner(value) {
    return typeof value === "string" ? value.trim() : "";
}

function normalizeGeneration(value) {
    const generation = Number(value);
    return Number.isFinite(generation) && generation >= 0 ? Math.floor(generation) : 0;
}

function snapshot(owner, pendingOwner, generation, phase, shouldSchedule, violation) {
    return Object.freeze({
        owner: normalizeOwner(owner),
        pendingOwner: normalizeOwner(pendingOwner),
        generation: normalizeGeneration(generation),
        phase: typeof phase === "string" ? phase : "idle",
        shouldSchedule: shouldSchedule === true,
        violation: typeof violation === "string" ? violation.trim() : "",
    });
}

function stateOrInitial(current) {
    return current && typeof current === "object" ? current : initial();
}

function initial() {
    return snapshot("", "", 0, "idle", false, "");
}

function request(current, ownerId) {
    const state = stateOrInitial(current);
    const owner = normalizeOwner(ownerId);
    if (!owner)
        return snapshot(state.owner, state.pendingOwner, state.generation,
            state.phase, state.shouldSchedule, "missing-focus-owner");

    if (state.owner === owner && state.phase === "owned")
        return snapshot(state.owner, "", state.generation, "owned", false, "");

    const generation = normalizeGeneration(state.generation) + 1;
    if (!state.owner && state.phase === "idle")
        return snapshot(owner, "", generation, "owned", false, "");

    return snapshot("", owner, generation, "releasing", true, "");
}

function withdraw(current, ownerId) {
    const state = stateOrInitial(current);
    const owner = normalizeOwner(ownerId);
    if (!owner)
        return snapshot(state.owner, state.pendingOwner, state.generation,
            state.phase, state.shouldSchedule, "missing-focus-owner");

    if (state.owner === owner)
        return snapshot("", "", state.generation, "idle", false, "");

    if (state.pendingOwner === owner)
        return snapshot(state.owner, "", state.generation,
            state.owner ? "owned" : "idle", false, "");

    return state;
}

function grantPending(current, generation) {
    const state = stateOrInitial(current);
    if (normalizeGeneration(generation) !== normalizeGeneration(state.generation))
        return state;
    if (state.phase !== "releasing" || state.owner || !state.pendingOwner)
        return state;
    return snapshot(state.pendingOwner, "", state.generation, "owned", false, "");
}
