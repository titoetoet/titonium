.pragma library

const pages = ["overview", "tools", "session"];

function normalizePage(pageId) {
    return pages.indexOf(pageId) >= 0 ? pageId : "overview";
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
    const previous = pages.indexOf(normalizePage(previousPage));
    const next = pages.indexOf(normalizePage(nextPage));
    const numericDuration = Number(configuredDuration);
    const duration = reducedMotion ? 0
        : Math.max(80, Math.min(220, Math.round(isFinite(numericDuration) ? numericDuration : 160)));
    return {
        duration: duration,
        offset: next >= previous ? 12 : -12
    };
}
