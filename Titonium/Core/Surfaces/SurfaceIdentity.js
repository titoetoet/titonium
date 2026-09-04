.pragma library

function matches(currentOwnerId, currentDescriptor, currentScreen,
        requestOwnerId, requestDescriptor, requestScreen) {
    return String(requestOwnerId || "").length > 0
        && currentOwnerId === requestOwnerId
        && currentDescriptor === requestDescriptor
        && currentScreen === requestScreen
        && requestDescriptor !== null
        && requestScreen !== null;
}
