.pragma library

function initialState() { return Object.freeze({feedback: null, selected: null}); }
function screenshot(descriptor, now, directory) {
    if (descriptor?.summary !== "Screenshot saved" || !descriptor.key) return null;
    var path = descriptor.body;
    if (typeof path !== "string" || !directory || !path.startsWith(directory + "/")
            || path.slice(directory.length + 1).includes("/") || !/\.png$/i.test(path)
            || /[\x00-\x1f]/.test(path)) return null;
    var id = "capture:screenshot:" + descriptor.key;
    var context = Object.freeze({id: id, source: "capture", kind: "screenshot",
        title: "Screenshot saved", subtitle: "", icon: "image", tone: "positive",
        attention: "ambient", progress: null, occurredAt: now, expiresAt: 0,
        details: Object.freeze({imageUrl: "file://" + path.split("/").map(encodeURIComponent).join("/")}),
        actionIds: Object.freeze([])});
    return Object.freeze({id: id, contextId: id, kind: "screenshot_saved",
        context: context, expiresAt: now + 6000});
}
function recording(startedAt, now) {
    return Object.freeze({id: "capture:started:" + startedAt, contextId: "capture:recording:" + startedAt,
        kind: "recording_started", context: null, expiresAt: now + 6000});
}
function publish(state, event) {
    if (!event || state.feedback?.id === event.id) return state;
    return Object.freeze({feedback: event, selected: state.selected});
}
function expire(state, id, now) {
    if (!state.feedback || state.feedback.id !== id || state.feedback.expiresAt > now) return state;
    return Object.freeze({feedback: null, selected: state.selected});
}
function select(state, contextId) {
    var selected = contexts(state).find(function(item) { return item.id === contextId; }) || null;
    if (selected === state.selected) return state;
    return Object.freeze({feedback: state.feedback, selected: selected});
}
function contexts(state) {
    var values = state.feedback?.context ? [state.feedback.context] : [];
    if (state.selected && !values.some(function(item) { return item.id === state.selected.id; }))
        values.push(state.selected);
    return Object.freeze(values);
}
function project(selection, values, feedback) {
    var primary = values.find(function(item) { return item.id === selection.primaryId; }) || null;
    var secondary = values.find(function(item) { return item.id === selection.secondaryId; }) || null;
    var target = feedback?.context || values.find(function(item) { return item.id === feedback?.contextId; });
    if (feedback && target) {
        secondary = primary?.id !== target.id ? primary : secondary;
        primary = Object.freeze(Object.assign({}, target, {details: Object.freeze(Object.assign({}, target.details,
            {feedbackKind: feedback.kind}))}));
    }
    var recordingIndicator = values.find(function(item) {
        return item.kind === "screen-recording" && item.id !== primary?.id && item.id !== secondary?.id;
    }) || null;
    return Object.freeze({idle: !primary, primary: primary, secondary: secondary,
        recordingIndicator: recordingIndicator});
}
