pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import "SurfaceIdentity.js" as SurfaceIdentity

QtObject {
    id: root

    property string ownerId: ""
    property var descriptor: null
    property var screen: null
    property string closingOwnerId: ""
    property var closingDescriptor: null
    property var closingScreen: null
    readonly property bool active: root.ownerId.length > 0 && root.descriptor !== null

    signal opened(string ownerId, var descriptor, var screen)
    signal closed(string ownerId)

    function matches(requestOwnerId: string, requestDescriptor: var,
            requestScreen: var): bool {
        return SurfaceIdentity.matches(root.ownerId, root.descriptor, root.screen,
            requestOwnerId, requestDescriptor, requestScreen);
    }

    function clearClosing(): void {
        root.closingOwnerId = "";
        root.closingDescriptor = null;
        root.closingScreen = null;
    }

    function beginClose(requestOwnerId: string, requestDescriptor: var,
            requestScreen: var): bool {
        if (!root.matches(requestOwnerId, requestDescriptor, requestScreen))
            return false;
        root.closingOwnerId = requestOwnerId;
        root.closingDescriptor = requestDescriptor;
        root.closingScreen = requestScreen;
        return true;
    }

    function isClosing(requestOwnerId: string, requestDescriptor: var,
            requestScreen: var): bool {
        return root.closingOwnerId === requestOwnerId
            && root.closingDescriptor === requestDescriptor
            && root.closingScreen === requestScreen
            && root.matches(requestOwnerId, requestDescriptor, requestScreen);
    }

    function closeOwned(requestOwnerId: string, requestDescriptor: var,
            requestScreen: var): bool {
        if (!root.matches(requestOwnerId, requestDescriptor, requestScreen))
            return false;
        return root.close(requestOwnerId);
    }

    function open(requestOwnerId: string, requestDescriptor: var, requestScreen: var): bool {
        if (!requestOwnerId || !requestDescriptor || !requestScreen)
            return false;
        root.clearClosing();
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
        root.clearClosing();
        root.ownerId = "";
        root.descriptor = null;
        root.screen = null;
        root.closed(previousOwner);
        return true;
    }
}
