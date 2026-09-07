.pragma library
function initial() { return { regions: [], contextId: '', openAt: 0, closeAt: 0 }; }
function enter(state, region, contextId, now, compact) {
    var regions = state.regions.filter(value => value !== region).concat([region]);
    return { regions: regions, contextId: compact ? contextId : state.contextId,
        openAt: compact ? (state.openAt && state.contextId === contextId ? state.openAt : now + 300) : 0,
        closeAt: 0 };
}
function leave(state, region, now) {
    var regions = state.regions.filter(value => value !== region);
    return { regions: regions, contextId: state.contextId,
        openAt: regions.length ? state.openAt : 0,
        closeAt: regions.length ? 0 : now + 250 };
}
function due(state, now) {
    return state.openAt && now >= state.openAt ? 'open'
        : state.closeAt && now >= state.closeAt ? 'close' : '';
}
