.pragma library

const PRIMARY_PAGES = Object.freeze([
    Object.freeze({ id: "overview", icon: "dashboard" }),
]);
const pages = PRIMARY_PAGES.map(page => page.id);

function primaryPages() {
    return Object.freeze(PRIMARY_PAGES.slice());
}

function normalizePage(pageId) {
    return pageId === "notifications" ? "notifications" : "overview";
}

function arrowPage(pageId, delta) {
    const current = pages.indexOf(normalizePage(pageId));
    return pages[(current + (delta < 0 ? -1 : 1) + pages.length) % pages.length];
}

function wheelPage(pageId, delta) {
    const current = pages.indexOf(normalizePage(pageId));
    return pages[Math.max(0, Math.min(pages.length - 1, current + (delta < 0 ? -1 : 1)))];
}

function transitionPlan(previousPage, nextPage, reducedMotion, configuredDuration) {
    const previous = normalizePage(previousPage) === "notifications" ? 1 : 0;
    const next = normalizePage(nextPage) === "notifications" ? 1 : 0;
    const numericDuration = Number(configuredDuration);
    const duration = reducedMotion ? 0
        : Math.max(80, Math.min(220, Math.round(isFinite(numericDuration) ? numericDuration : 160)));
    return {
        duration: duration,
        offset: next >= previous ? 12 : -12
    };
}

function pinTransition(owner, requestedScreen, pinned, action) {
    const current = typeof owner === "string" ? owner.trim() : "";
    const requested = typeof requestedScreen === "string" ? requestedScreen.trim() : "";
    if (action === "close")
        return { ownerScreenName: "", pinned: false, shouldClose: true };
    if (!requested)
        return { ownerScreenName: current, pinned: Boolean(pinned), shouldClose: false };
    if (current === requested && pinned === true)
        return { ownerScreenName: "", pinned: false, shouldClose: true };
    return { ownerScreenName: requested, pinned: true, shouldClose: false };
}
