pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces
import "CenterNotchState.js" as CenterNotchState

QtObject {
    id: root

    property string ownerScreenName: ""
    property string exitingScreenName: ""
    property string requestedPage: "overview"
    property bool pinned: false
    readonly property bool active: root.ownerScreenName.length > 0

    function open(screenName: string, pageId: string): bool {
        if (!screenName)
            return false;
        SurfaceManager.close("");
        root.exitingScreenName = "";
        root.ownerScreenName = screenName;
        root.requestedPage = CenterNotchState.normalizePage(pageId);
        root.pinned = false;
        return true;
    }

    function toggle(screenName: string): bool {
        if (root.ownerScreenName === screenName)
            return root.close();
        return root.open(screenName, "overview");
    }

    function requestPage(pageId: string): bool {
        if (!root.active)
            return false;
        root.requestedPage = CenterNotchState.normalizePage(pageId);
        return true;
    }

    function togglePinned(screenName: string): bool {
        if (!screenName)
            return false;
        const transition = CenterNotchState.pinTransition(
            root.ownerScreenName, screenName, root.pinned, "toggle");
        if (transition.shouldClose)
            return root.close();
        SurfaceManager.close("");
        if (root.ownerScreenName !== transition.ownerScreenName)
            root.requestedPage = "overview";
        root.ownerScreenName = transition.ownerScreenName;
        root.pinned = transition.pinned;
        return true;
    }

    function close(): bool {
        root.exitingScreenName = root.ownerScreenName;
        root.ownerScreenName = "";
        root.requestedPage = "overview";
        root.pinned = false;
        return true;
    }

    function finishClose(screenName: string): void {
        if (root.exitingScreenName === screenName)
            root.exitingScreenName = "";
    }
}
