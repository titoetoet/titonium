// Pure candidate operations. Persistence belongs to Preferences; no runtime side effects.
function clone(value) { return JSON.parse(JSON.stringify(value)); }
function same(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
function pick(settings) {
    return {appearance: clone(settings.appearance || {}),
        reducedMotion: settings.accessibility?.reducedMotion === true};
}
function mergeCandidate(settings, base, candidate) {
    const result = clone(settings);
    if (!same(base.appearance, candidate.appearance))
        result.appearance = clone(candidate.appearance);
    if (base.reducedMotion !== candidate.reducedMotion) {
        result.accessibility = result.accessibility || {};
        result.accessibility.reducedMotion = candidate.reducedMotion;
    }
    return result;
}
function override(candidate, mode, key, value) {
    const result = clone(candidate);
    const allowed = ['accent','backgroundOpacity','borderStrength','shadowStrength',
        'sheenStrength','radiusScale','motionScale'];
    if (['light','dark'].indexOf(mode) < 0 || allowed.indexOf(key) < 0)
        return result;
    const id = result.appearance.themeId;
    if (['glassmorphism','material','liquid-glass','modern-flat','neumorphism',
        'neutral','glass','soft','graphite'].indexOf(id) < 0) return result;
    const all = result.appearance.themeOverrides || {};
    const theme = all[id] || {};
    const values = theme[mode] || {};
    if (value === null) delete values[key]; else values[key] = value;
    theme[mode] = values; all[id] = theme; result.appearance.themeOverrides = all;
    return result;
}
function trial(generation, now, candidate) {
    return {generation: generation, deadline: now + 15000, candidate: clone(candidate)};
}
function expired(trialState, now, generation) {
    return !!trialState && trialState.generation === generation && now >= trialState.deadline;
}
function restoreAppearance(current, before, after, restoreMotion) {
    const result = clone(current);
    result.appearance = clone(before.appearance);
    if (restoreMotion && current.accessibility?.reducedMotion === after.accessibility?.reducedMotion) {
        result.accessibility = result.accessibility || {};
        result.accessibility.reducedMotion = before.accessibility?.reducedMotion === true;
    }
    return result;
}
