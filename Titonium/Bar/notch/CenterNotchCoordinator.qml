pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces
import "CenterNotchState.js" as CenterNotchState

QtObject {
    id: root

    property string ownerScreenName: ""
    property string requestedPage: "overview"
    readonly property bool active: root.ownerScreenName.length > 0

    function open(screenName: string, pageId: string): bool {
        if (!screenName)
            return false;
        SurfaceManager.close("");
        root.ownerScreenName = screenName;
        root.requestedPage = CenterNotchState.normalizePage(pageId);
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

    function close(): bool {
        root.ownerScreenName = "";
        root.requestedPage = "overview";
        return true;
    }
}
