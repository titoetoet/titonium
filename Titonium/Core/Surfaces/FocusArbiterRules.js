.pragma library

function normalizeOwner(value) {
    return typeof value === "string" ? value.trim() : "";
}

function normalizeLease(value) {
    return typeof value === "string" ? value.trim() : "";
}

function normalizeGeneration(value) {
    const generation = Number(value);
    return Number.isSafeInteger(generation) && generation >= 0 ? generation : 0;
}

function normalizePhase(value) {
    return value === "owned" || value === "releasing" ? value : "idle";
}

function nextGeneration(value) {
    const generation = normalizeGeneration(value);
    return generation < Number.MAX_SAFE_INTEGER ? generation + 1 : generation;
}

function snapshot(owner, ownerLease, pendingOwner, pendingLease, generation,
        phase, shouldSchedule, violation) {
    const result = {
        owner: normalizeOwner(owner),
        pendingOwner: normalizeOwner(pendingOwner),
        generation: normalizeGeneration(generation),
        phase: normalizePhase(phase),
        shouldSchedule: shouldSchedule === true,
        violation: typeof violation === "string" ? violation.trim() : "",
    };
    Object.defineProperties(result, {
        ownerLease: {
            value: normalizeLease(ownerLease), enumerable: false,
            writable: false, configurable: false,
        },
        pendingLease: {
            value: normalizeLease(pendingLease), enumerable: false,
            writable: false, configurable: false,
        },
    });
    return Object.freeze(result);
}

function isCanonicalState(state) {
    return Object.isFrozen(state)
        && state.owner === normalizeOwner(state.owner)
        && state.ownerLease === normalizeLease(state.ownerLease)
        && state.pendingOwner === normalizeOwner(state.pendingOwner)
        && state.pendingLease === normalizeLease(state.pendingLease)
        && state.generation === normalizeGeneration(state.generation)
        && state.phase === normalizePhase(state.phase)
        && state.shouldSchedule === (state.shouldSchedule === true)
        && state.violation === (typeof state.violation === "string"
            ? state.violation.trim() : "");
}

function canonicalState(current) {
    if (!current || typeof current !== "object")
        return initial();
    if (isCanonicalState(current))
        return current;
    return snapshot(current.owner, current.ownerLease, current.pendingOwner,
        current.pendingLease, current.generation, current.phase,
        current.shouldSchedule, current.violation);
}

function initial() {
    return snapshot("", "", "", "", 0, "idle", false, "");
}

function request(current, ownerId, lease) {
    const state = canonicalState(current);
    const owner = normalizeOwner(ownerId);
    const requesterLease = normalizeLease(lease);
    if (!owner)
        return snapshot(state.owner, state.ownerLease, state.pendingOwner,
            state.pendingLease, state.generation, state.phase,
            state.shouldSchedule, "missing-focus-owner");
    if (!requesterLease)
        return snapshot(state.owner, state.ownerLease, state.pendingOwner,
            state.pendingLease, state.generation, state.phase,
            state.shouldSchedule, "missing-focus-lease");

    if (state.owner === owner && state.ownerLease === requesterLease
            && state.phase === "owned")
        return state;
    if (state.pendingOwner === owner && state.pendingLease === requesterLease
            && state.phase === "releasing")
        return state;

    const generation = nextGeneration(state.generation);
    if (!state.owner && state.phase === "idle")
        return snapshot(owner, requesterLease, "", "", generation,
            "owned", false, "");
    if (!state.owner && state.phase === "releasing" && !state.pendingOwner)
        return snapshot("", "", owner, requesterLease, state.generation,
            "releasing", true, "");
    return snapshot("", "", owner, requesterLease, generation,
        "releasing", true, "");
}

function withdraw(current, ownerId, lease) {
    const state = canonicalState(current);
    const owner = normalizeOwner(ownerId);
    const requesterLease = normalizeLease(lease);
    if (!owner)
        return snapshot(state.owner, state.ownerLease, state.pendingOwner,
            state.pendingLease, state.generation, state.phase,
            state.shouldSchedule, "missing-focus-owner");
    if (!requesterLease)
        return snapshot(state.owner, state.ownerLease, state.pendingOwner,
            state.pendingLease, state.generation, state.phase,
            state.shouldSchedule, "missing-focus-lease");

    if (state.owner === owner && state.ownerLease === requesterLease)
        return snapshot("", "", "", "", nextGeneration(state.generation),
            "releasing", true, "");
    if (state.pendingOwner === owner && state.pendingLease === requesterLease)
        return snapshot("", "", "", "", state.generation,
            "releasing", true, "");
    return state;
}

function grantPending(current, generation, lease) {
    const state = canonicalState(current);
    if (typeof generation !== "number" || !Number.isSafeInteger(generation)
            || generation < 0 || generation !== state.generation)
        return state;
    if (arguments.length >= 3
            && normalizeLease(lease) !== state.pendingLease)
        return state;
    if (state.phase !== "releasing" || state.owner)
        return state;
    if (!state.pendingOwner)
        return snapshot("", "", "", "", state.generation,
            "idle", false, "");
    return snapshot(state.pendingOwner, state.pendingLease, "", "",
        state.generation, "owned", false, "");
}
