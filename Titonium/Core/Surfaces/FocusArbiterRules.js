.pragma library

function normalizeOwner(value) {
    return typeof value === "string" ? value.trim() : "";
}

function normalizeGeneration(value) {
    const generation = Number(value);
    return Number.isSafeInteger(generation) && generation >= 0 ? generation : 0;
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
    if (state.pendingOwner === owner && state.phase === "releasing")
        return state;

    const generation = normalizeGeneration(state.generation) + 1;
    if (!state.owner && state.phase === "idle")
        return snapshot(owner, "", generation, "owned", false, "");
    if (!state.owner && state.phase === "releasing" && !state.pendingOwner)
        return snapshot("", owner, state.generation, "releasing", true, "");

    return snapshot("", owner, generation, "releasing", true, "");
}

function withdraw(current, ownerId) {
    const state = stateOrInitial(current);
    const owner = normalizeOwner(ownerId);
    if (!owner)
        return snapshot(state.owner, state.pendingOwner, state.generation,
            state.phase, state.shouldSchedule, "missing-focus-owner");

    if (state.owner === owner)
        return snapshot("", "", normalizeGeneration(state.generation) + 1,
            "releasing", true, "");

    if (state.pendingOwner === owner)
        return snapshot("", "", state.generation, "releasing", true, "");

    return state;
}

function grantPending(current, generation) {
    const state = stateOrInitial(current);
    if (typeof generation !== "number" || !Number.isSafeInteger(generation)
            || generation < 0 || generation !== state.generation)
        return state;
    if (state.phase !== "releasing" || state.owner)
        return state;
    if (!state.pendingOwner)
        return snapshot("", "", state.generation, "idle", false, "");
    return snapshot(state.pendingOwner, "", state.generation, "owned", false, "");
}
