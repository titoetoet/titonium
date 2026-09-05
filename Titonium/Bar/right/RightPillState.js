.pragma library

function clamp01(value) {
    return Math.max(0, Math.min(1, Number(value) || 0));
}

function normalizeState(active) {
    return active === true ? "menu" : "compact";
}

function menuHeight(contentHeight, outputHeight) {
    const output = Number(outputHeight);
    const available = Number.isFinite(output) ? Math.max(0, output) : 36;
    const requested = Math.max(120, Math.min(440,
        Math.max(0, Number(contentHeight) || 0) + 32));
    return Math.min(available, requested);
}

function menuWidth(contentWidth, sourceWidth) {
    const content = Math.max(0, Number(contentWidth) || 0);
    const source = Math.max(0, Number(sourceWidth) || 0);
    return Math.max(240, Math.min(520, Math.max(content, source) + 32));
}

function contentOpacity(progress, layer) {
    const value = clamp01(progress);
    if (layer === "compact")
        return 1 - Math.min(1, value / 0.35);
    return Math.max(0, Math.min(1, (value - 0.2) / 0.55));
}

function inputMode(progress, active) {
    if (active !== true)
        return "compact";
    const value = clamp01(progress);
    return value < 0.35 ? "compact" : (value > 0.7 ? "menu" : "handoff");
}

function shouldDismissTap(activeEdge, inLeftPill, inRightPill, inBranch) {
    if (inBranch === true)
        return false;
    const inOwnerPill = activeEdge === "left"
        ? inLeftPill === true : inRightPill === true;
    return !inOwnerPill;
}

function connectedInitialState(generation) {
    const value = Math.max(0, Math.floor(Number(generation) || 0));
    return Object.freeze({
        generation: value,
        ownerId: "",
        descriptor: null,
        screen: null,
        closing: false,
        closingGeneration: 0,
        focusReturned: false,
    });
}

function connectedDescriptorSnapshot(descriptor) {
    if (!descriptor || descriptor.barConnected !== true)
        return null;
    return Object.freeze({
        ownerId: String(descriptor.ownerId || ""),
        feature: String(descriptor.feature || ""),
        source: descriptor.source || "",
        anchor: String(descriptor.anchor || ""),
        invoker: descriptor.invoker || null,
        barConnected: true,
    });
}

function matchesSurfaceOpen(managerOwnerId, managerDescriptor, managerScreen,
        ownerId, descriptor, screen) {
    return String(ownerId || "").length > 0
        && managerOwnerId === ownerId
        && managerDescriptor === descriptor
        && managerScreen === screen
        && descriptor !== null
        && screen !== null;
}

function matchesConnectedSnapshot(current, ownerId, generation, descriptor, screen) {
    return current !== null && current !== undefined
        && current.ownerId === String(ownerId || "")
        && current.generation === Number(generation)
        && current.descriptor === descriptor
        && current.screen === screen
        && descriptor !== null
        && screen !== null;
}

function connectedOpen(current, ownerId, descriptor, screen) {
    const owner = String(ownerId || "");
    const snapshot = connectedDescriptorSnapshot(descriptor);
    if (!owner || !snapshot || !snapshot.source || !snapshot.anchor || !screen)
        return current;
    const generation = Math.max(0, Math.floor(Number(current?.generation) || 0)) + 1;
    return Object.freeze({
        generation: generation,
        ownerId: owner,
        descriptor: snapshot,
        screen: screen,
        closing: false,
        closingGeneration: 0,
        focusReturned: false,
    });
}

function connectedRequestClose(current, ownerId, generation) {
    if (!current || current.closing === true
            || current.ownerId !== String(ownerId || "")
            || current.generation !== Number(generation))
        return current;
    return Object.freeze({
        generation: current.generation,
        ownerId: current.ownerId,
        descriptor: current.descriptor,
        screen: current.screen,
        closing: true,
        closingGeneration: current.generation,
        focusReturned: current.focusReturned === true,
    });
}

function connectedMarkFocusReturned(current, ownerId, generation) {
    if (!current || current.closing !== true || current.focusReturned === true
            || current.ownerId !== String(ownerId || "")
            || current.closingGeneration !== Number(generation))
        return current;
    return Object.freeze({
        generation: current.generation,
        ownerId: current.ownerId,
        descriptor: current.descriptor,
        screen: current.screen,
        closing: true,
        closingGeneration: current.closingGeneration,
        focusReturned: true,
    });
}

function canReturnConnectedFocus(current, ownerId, generation,
        managerOwnerId, managerActive, managerReleased) {
    if (!current || current.closing !== true || current.focusReturned === true
            || current.ownerId !== String(ownerId || "")
            || current.closingGeneration !== Number(generation))
        return false;
    if (managerReleased === true)
        return managerActive !== true;
    return managerActive === true && managerOwnerId === ownerId;
}

function connectedFinishClose(current, ownerId, generation) {
    if (!current || current.closing !== true
            || current.ownerId !== String(ownerId || "")
            || current.closingGeneration !== Number(generation))
        return current;
    return connectedInitialState(current.generation);
}

function connectedClear(current, ownerId, generation) {
    if (!current || current.ownerId !== String(ownerId || "")
            || current.generation !== Number(generation))
        return current;
    return connectedInitialState(current.generation);
}

function shouldFinalizeMenuForConnected(menuActive, exitingScreenName) {
    return menuActive === true || String(exitingScreenName || "").length > 0;
}
