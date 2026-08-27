function project(document, defaults) {
    const source = document && typeof document === "object" ? document : {};
    const fallback = defaults && typeof defaults === "object" ? defaults : {};
    const transition = source.modules?.spotlight?.pageTransition;
    const duration = source.modules?.spotlight?.transitionDuration;
    return {
        locale: source.locale === "en" ? "en" : (fallback.locale || "vi"),
        appearance: {
            mode: source.appearance?.mode === "light" ? "light" : "dark"
        },
        accessibility: {
            reducedMotion: source.accessibility?.reducedMotion === true
        },
        applications: {
            hiddenIds: Array.isArray(source.applications?.hiddenIds)
                ? source.applications.hiddenIds.filter(id => typeof id === "string") : []
        },
        modules: {
            spotlight: {
                pageTransition: ["slide-fade", "fade", "none"].indexOf(transition) >= 0
                    ? transition : "slide-fade",
                transitionDuration: Number.isInteger(duration)
                    ? Math.max(0, Math.min(500, duration)) : 220
            },
            clock: {
                use24Hour: source.modules?.clock?.use24Hour !== false
            },
            audio: {
                allowAmplification: source.schemaVersion === 6
                    && source.modules?.audio?.allowAmplification === true
            }
        }
    };
}
