pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.SystemTray
import qs.Titonium.Theme
import "RightPillState.js" as RightPillState

QtObject {
    id: root

    property string ownerScreenName: ""
    property string exitingScreenName: ""
    property string menuSource: ""
    property string activeEdge: ""
    property string exitingEdge: ""
    property real leftCompactWidth: 420
    property real rightCompactWidth: 220
    readonly property real compactWidth: root.rightCompactWidth
    property bool leftHovered: false
    property bool rightHovered: false
    readonly property bool hovered: root.leftHovered || root.rightHovered
    readonly property bool menuActive: root.ownerScreenName.length > 0
    readonly property bool connectedSurfaceActive: SurfaceManager.active
        && SurfaceManager.descriptor?.barConnected === true
    readonly property bool presentationActive: root.menuActive || root.connectedSurfaceActive
    property real transitionProgress: root.presentationActive ? 1 : 0
    readonly property bool active: root.menuActive
    readonly property string state: RightPillState.normalizeState(root.presentationActive)

    function setCompactWidth(edge: string, width: real): void {
        const value = Number(width) || 0;
        if (value <= 0)
            return;
        if (edge === "left")
            root.leftCompactWidth = value;
        else if (edge === "right")
            root.rightCompactWidth = value;
    }

    function beginOpen(screenName: string, edge: string, source: string): bool {
        if (!screenName || (edge !== "left" && edge !== "right"))
            return false;
        root.exitingScreenName = "";
        root.exitingEdge = "";
        root.menuSource = source;
        root.activeEdge = edge;
        root.ownerScreenName = screenName;
        return true;
    }

    function toggleApp(screenName: string, edge: string, appId: string, appName: string): bool {
        const source = "app:" + appId + ":" + appName;
        if (root.active && root.ownerScreenName === screenName
                && root.activeEdge === edge && root.menuSource === source)
            return root.close();
        if (!SystemTrayService.prepareAppMenu(appId, appName))
            return false;
        return root.beginOpen(screenName, edge, source);
    }

    function toggleInput(screenName: string, edge: string): bool {
        if (root.active && root.ownerScreenName === screenName
                && root.activeEdge === edge && root.menuSource === "input")
            return root.close();
        if (!SystemTrayService.prepareInputMenu())
            return false;
        return root.beginOpen(screenName, edge, "input");
    }

    function close(): bool {
        if (!root.active)
            return false;
        root.exitingScreenName = root.ownerScreenName;
        root.exitingEdge = root.activeEdge;
        root.ownerScreenName = "";
        root.activeEdge = "";
        return true;
    }

    function closeConnectedSurface(): bool {
        if (!root.connectedSurfaceActive)
            return false;
        return SurfaceManager.close(SurfaceManager.ownerId);
    }

    function finishClose(screenName: string): void {
        if (!screenName || root.exitingScreenName !== screenName || root.active)
            return;
        root.exitingScreenName = "";
        root.exitingEdge = "";
        root.menuSource = "";
        SystemTrayService.resetPopupNavigation();
    }

    Behavior on transitionProgress {
        NumberAnimation {
            duration: Motion.reduced ? 0 : (root.presentationActive ? 240 : 190)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
            onFinished: {
                if (!root.active && root.exitingScreenName.length > 0)
                    root.finishClose(root.exitingScreenName);
            }
        }
    }

    property Connections menuValidityConnection: Connections {
        target: SystemTrayService
        function onPopupPreparedChanged(): void {
            if (root.menuActive && !SystemTrayService.popupPrepared)
                root.close();
        }
    }
}
