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

    function open(requestOwnerId: string, requestDescriptor: var, requestScreen: var): void {
        if (!requestOwnerId || !requestDescriptor)
            return;
        root.ownerId = requestOwnerId;
        root.descriptor = requestDescriptor;
        root.screen = requestScreen;
        root.opened(requestOwnerId, requestDescriptor, requestScreen);
    }

    function close(requestOwnerId: string): void {
        if (requestOwnerId && requestOwnerId !== root.ownerId)
            return;
        const previousOwner = root.ownerId;
        root.ownerId = "";
        root.descriptor = null;
        root.screen = null;
        root.closed(previousOwner);
    }
}

