pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property string ownerId: ""
    property var descriptor: null
    property var screen: null
    readonly property bool active: root.ownerId.length > 0 && root.descriptor !== null

    signal opened(string ownerId, var descriptor, var screen)
    signal closed(string ownerId)

    function open(requestOwnerId: string, requestDescriptor: var, requestScreen: var): bool {
        if (!requestOwnerId || !requestDescriptor || !requestScreen)
            return false;
        root.ownerId = requestOwnerId;
        root.descriptor = requestDescriptor;
        root.screen = requestScreen;
        root.opened(requestOwnerId, requestDescriptor, requestScreen);
        return true;
    }

    function close(requestOwnerId: string): bool {
        if (requestOwnerId && requestOwnerId !== root.ownerId)
            return false;
        const previousOwner = root.ownerId;
        root.ownerId = "";
        root.descriptor = null;
        root.screen = null;
        root.closed(previousOwner);
        return true;
    }
}
