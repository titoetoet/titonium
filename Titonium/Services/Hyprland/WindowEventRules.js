.pragma library

// These IPC events cannot change the window descriptors or workspace ownership.
// Unknown events retain the refresh fallback for forward compatibility.
// Event definitions: https://wiki.hypr.land/IPC/#events-list
function requiresProjection(name) {
    return ["activelayout", "openlayer", "closelayer", "submap", "screencast",
        "screencastv2", "ignoregrouplock", "lockgroups", "bell"].indexOf(name) < 0;
}
