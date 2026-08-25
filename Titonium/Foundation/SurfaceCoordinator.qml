pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property string ownerId: ""
    property string guardedOwnerId: ""
    property var descriptor: null
    property var screen: null
    readonly property bool active: root.ownerId.length > 0 && root.descriptor !== null
    readonly property bool ownerGuarded: root.guardedOwnerId.length > 0
        && root.guardedOwnerId === root.ownerId

    signal opened(string ownerId, var descriptor, var screen)
    signal closed(string ownerId)

    function cancelPreviewIfOwned(surfaceDescriptor: var): void {
        if (surfaceDescriptor?.cancelPreviewOnClose === true && ConfigStore.previewActive)
            ConfigStore.cancel();
    }

    function guardOwner(requestOwnerId: string): bool {
        if (!root.active || requestOwnerId.length === 0
                || requestOwnerId !== root.ownerId || root.ownerGuarded)
            return false;
        root.guardedOwnerId = requestOwnerId;
        return true;
    }

    function releaseOwnerGuard(requestOwnerId: string): bool {
        if (requestOwnerId.length === 0 || requestOwnerId !== root.guardedOwnerId)
            return false;
        root.guardedOwnerId = "";
        return true;
    }

    function open(requestOwnerId: string, requestDescriptor: var, requestScreen: var): bool {
        if (!requestOwnerId || !requestDescriptor)
            return false;
        if (root.ownerGuarded) {
            if (requestOwnerId !== root.ownerId)
                root.cancelPreviewIfOwned(requestDescriptor);
            return false;
        }
        if (root.active && root.ownerId !== requestOwnerId)
            root.cancelPreviewIfOwned(root.descriptor);
        root.ownerId = requestOwnerId;
        root.descriptor = requestDescriptor;
        root.screen = requestScreen;
        root.opened(requestOwnerId, requestDescriptor, requestScreen);
        return true;
    }

    function closeNow(requestOwnerId: string): bool {
        if (requestOwnerId && requestOwnerId !== root.ownerId)
            return false;
        const previousOwner = root.ownerId;
        const previousDescriptor = root.descriptor;
        root.ownerId = "";
        root.guardedOwnerId = "";
        root.descriptor = null;
        root.screen = null;
        root.cancelPreviewIfOwned(previousDescriptor);
        root.closed(previousOwner);
        return true;
    }

    function close(requestOwnerId: string): bool {
        if (root.ownerGuarded)
            return false;
        return root.closeNow(requestOwnerId);
    }

    function forceClose(requestOwnerId: string): bool {
        if (!root.ownerGuarded || requestOwnerId.length === 0
                || requestOwnerId !== root.guardedOwnerId)
            return false;
        root.guardedOwnerId = "";
        return root.closeNow(requestOwnerId);
    }
}
