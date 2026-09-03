function record(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value)
        ? value : {};
}

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

function same(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
}

function setPath(document, path, value) {
    const segments = typeof path === "string" ? path.split(".") : [];
    const forbidden = ["__proto__", "prototype", "constructor"];
    if (segments.length === 0 || segments.some(segment => segment.length === 0
            || forbidden.indexOf(segment) >= 0))
        throw new Error("preference path must contain non-empty segments");
    const result = clone(record(document));
    let cursor = result;
    for (let index = 0; index < segments.length - 1; index++) {
        const segment = segments[index];
        cursor[segment] = clone(record(cursor[segment]));
        cursor = cursor[segment];
    }
    cursor[segments[segments.length - 1]] = clone(value);
    return result;
}

function normalizeIds(values, caseInsensitive) {
    const source = Array.isArray(values) ? values : [];
    const seen = Object.create(null);
    const result = [];
    for (let index = 0; index < source.length; index++) {
        if (typeof source[index] !== "string")
            continue;
        const id = source[index].trim();
        const key = "$" + (caseInsensitive ? id.toLocaleLowerCase() : id);
        if (!id || seen[key])
            continue;
        seen[key] = true;
        result.push(id);
    }
    return result;
}

function normalizePinnedIds(values) {
    return normalizeIds(values, true);
}

function dockModeFromLegacy(document) {
    const source = record(document);
    if (source.pinnedOpen === true)
        return "reserve-space";
    if (source.autoHide === false)
        return "always-visible";
    return "auto-hide";
}

function oneOf(value, values, fallback) {
    return values.indexOf(value) >= 0 ? value : fallback;
}

function integer(value, fallback, minimum, maximum) {
    const candidate = Number.isInteger(value) ? value : fallback;
    return Math.max(minimum, Math.min(maximum, candidate));
}

function boolean(value, fallback) {
    return typeof value === "boolean" ? value : fallback;
}

function project(document, defaults, legacyDock) {
    const source = record(document);
    const fallback = record(defaults);
    const sourceModules = record(source.modules);
    const fallbackModules = record(fallback.modules);
    const fallbackAppearance = record(fallback.appearance);
    const fallbackAccessibility = record(fallback.accessibility);
    const fallbackApplications = record(fallback.applications);
    const fallbackSpotlight = record(fallbackModules.spotlight);
    const fallbackBar = record(fallbackModules.bar);
    const fallbackDock = record(fallbackModules.dock);
    const fallbackNotifications = record(fallbackModules.notifications);
    const fallbackClock = record(fallbackModules.clock);
    const fallbackAudio = record(fallbackModules.audio);

    const spotlight = record(sourceModules.spotlight);
    const bar = record(sourceModules.bar);
    const notifications = record(sourceModules.notifications);
    const clock = record(sourceModules.clock);
    const audio = record(sourceModules.audio);
    const currentDock = source.schemaVersion === 7
        && Object.prototype.hasOwnProperty.call(sourceModules, "dock")
        ? record(sourceModules.dock) : null;
    const dock = currentDock || (record(legacyDock).schemaVersion === 1
        ? {
            visibilityMode: dockModeFromLegacy(legacyDock),
            pinnedIds: record(legacyDock).pinnedIds,
        } : fallbackDock);

    return {
        $schema: "titonium.settings/v7",
        schemaVersion: 7,
        locale: oneOf(source.locale, ["vi", "en"],
            oneOf(fallback.locale, ["vi", "en"], "vi")),
        appearance: {
            mode: oneOf(record(source.appearance).mode, ["dark", "light"],
                oneOf(fallbackAppearance.mode, ["dark", "light"], "dark")),
        },
        accessibility: {
            reducedMotion: boolean(record(source.accessibility).reducedMotion,
                boolean(fallbackAccessibility.reducedMotion, false)),
        },
        applications: {
            hiddenIds: normalizeIds(
                Array.isArray(record(source.applications).hiddenIds)
                    ? record(source.applications).hiddenIds
                    : fallbackApplications.hiddenIds,
                false),
        },
        modules: {
            spotlight: {
                pageTransition: oneOf(spotlight.pageTransition,
                    ["slide-fade", "fade", "none"],
                    oneOf(fallbackSpotlight.pageTransition,
                        ["slide-fade", "fade", "none"], "slide-fade")),
                transitionDuration: integer(spotlight.transitionDuration,
                    integer(fallbackSpotlight.transitionDuration, 220, 0, 500), 0, 500),
            },
            bar: {
                workspaceCount: integer(bar.workspaceCount,
                    integer(fallbackBar.workspaceCount, 5, 1, 8), 1, 8),
                autoHide: boolean(bar.autoHide, boolean(fallbackBar.autoHide, false)),
                mascotEnabled: boolean(bar.mascotEnabled,
                    boolean(fallbackBar.mascotEnabled, true)),
                style: oneOf(bar.style, ["connected", "classic"],
                    oneOf(fallbackBar.style, ["connected", "classic"], "connected")),
            },
            dock: {
                visibilityMode: oneOf(dock.visibilityMode,
                    ["auto-hide", "always-visible", "reserve-space", "hidden"],
                    oneOf(fallbackDock.visibilityMode,
                        ["auto-hide", "always-visible", "reserve-space", "hidden"], "auto-hide")),
                pinnedIds: normalizePinnedIds(dock.pinnedIds),
            },
            notifications: {
                toastsEnabled: boolean(notifications.toastsEnabled,
                    boolean(fallbackNotifications.toastsEnabled, true)),
                toastDuration: integer(notifications.toastDuration,
                    integer(fallbackNotifications.toastDuration, 5000, 2000, 10000),
                    2000, 10000),
            },
            clock: {
                use24Hour: boolean(clock.use24Hour,
                    boolean(fallbackClock.use24Hour, true)),
            },
            audio: {
                allowAmplification: boolean(audio.allowAmplification,
                    boolean(fallbackAudio.allowAmplification, false)),
            },
        },
    };
}
