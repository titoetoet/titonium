pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces.Center
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Screens
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.SystemTray
import qs.Titonium.Theme
import "BarPopupRouting.js" as BarPopupRouting
import "EdgeMenuGeometry.js" as EdgeMenuGeometry
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
    property var invocationScreen: null
    property var invocationInvoker: null
    property string presentedStyle: ""
    readonly property bool hovered: root.leftHovered || root.rightHovered
    property var connectedState: RightPillState.connectedInitialState()
    readonly property bool connectedSurfacePresented:
        root.connectedState.ownerId.length > 0
    readonly property string connectedOwnerId: root.connectedState.ownerId
    readonly property int connectedGeneration: root.connectedState.generation
    readonly property var connectedDescriptor: root.connectedState.descriptor
    readonly property var connectedScreen: root.connectedState.screen
    readonly property bool connectedClosing: root.connectedState.closing
    readonly property bool menuActive: root.ownerScreenName.length > 0
    readonly property bool connectedSurfaceActive: root.connectedSurfacePresented
        && !root.connectedClosing
    readonly property bool presentationActive: root.menuActive || root.connectedSurfaceActive
    property real transitionProgress: root.presentationActive ? 1 : 0
    readonly property bool active: root.menuActive
    readonly property string state: RightPillState.normalizeState(root.presentationActive)

    Component.onCompleted: root.presentedStyle =
        BarPopupRouting.normalizeStyle(Preferences.barStyle)

    function setCompactWidth(edge: string, width: real): void {
        const value = Number(width) || 0;
        if (value <= 0)
            return;
        if (edge === "left")
            root.leftCompactWidth = value;
        else if (edge === "right")
            root.rightCompactWidth = value;
    }

    function systemTrayOwnerFor(screen: var, feature: string): string {
        return screen?.name ? "system-tray:" + screen.name + ":" + feature : "";
    }

    function setInvocationContext(screen: var, invoker: var): void {
        root.invocationScreen = screen;
        root.invocationInvoker = invoker;
    }

    function takeInvocationContext(screenName: string): var {
        const matches = root.invocationScreen?.name === screenName;
        const context = {
            "screen": matches ? root.invocationScreen : null,
            "invoker": matches ? root.invocationInvoker : null,
        };
        root.invocationScreen = null;
        root.invocationInvoker = null;
        return context;
    }

    function invokerAnchorSnapshot(invoker: var, edge: string, screen: var): var {
        if (!invoker || !screen)
            return null;
        let origin = null;
        try {
            origin = invoker.mapToItem(null, 0, 0);
        } catch (error) {
            return null;
        }
        return EdgeMenuGeometry.anchorSnapshot(edge, screen.name,
            origin.x, origin.y, invoker.width, invoker.height);
    }

    function openPrepared(screenName: string, edge: string, feature: string,
            source: string, screen: var, invoker: var): bool {
        const routedScreen = ScreenRouter.screenForName(screen?.name || screenName);
        const owner = root.systemTrayOwnerFor(routedScreen, feature);
        const route = BarPopupRouting.presentation(root.presentedStyle, feature);
        if (!owner || !route)
            return false;
        if (route.owner === "edge")
            return root.beginOpen(routedScreen.name, edge, source);
        if (!invoker)
            return false;
        const descriptor = {
            "source": Qt.resolvedUrl("../../Overlays/SystemTray/" + route.source),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": owner,
            "feature": feature,
            "barConnected": route.owner === "edge",
            "anchor": route.anchor,
            "invoker": invoker,
            "anchorRect": root.invokerAnchorSnapshot(invoker, edge, routedScreen),
            "anchorEdge": edge,
            "anchorScreenName": routedScreen.name,
        };
        return SurfaceManager.open(owner, descriptor, routedScreen);
    }

    function beginOpen(screenName: string, edge: string, source: string): bool {
        if (!screenName || (edge !== "left" && edge !== "right"))
            return false;
        root.clearConnectedForMenu();
        root.exitingScreenName = "";
        root.exitingEdge = "";
        root.menuSource = source;
        root.activeEdge = edge;
        root.ownerScreenName = screenName;
        return true;
    }

    function finalizeDisplacedMenu(): void {
        if (!RightPillState.shouldFinalizeMenuForConnected(
                root.menuActive, root.exitingScreenName))
            return;
        root.ownerScreenName = "";
        root.exitingScreenName = "";
        root.activeEdge = "";
        root.exitingEdge = "";
        root.menuSource = "";
        SystemTrayService.resetPopupNavigation();
    }

    function clearConnectedForMenu(): void {
        if (!root.connectedSurfacePresented)
            return;
        const ownerId = root.connectedOwnerId;
        const generation = root.connectedGeneration;
        root.connectedState = RightPillState.connectedClear(
            root.connectedState, ownerId, generation);
        if (SurfaceManager.ownerId === ownerId)
            SurfaceManager.close(ownerId);
    }

    function adoptConnectedSurface(ownerId: string, descriptor: var, screen: var): void {
        root.finalizeDisplacedMenu();
        const adopted = RightPillState.connectedOpen(
            root.connectedState, ownerId, descriptor, screen);
        if (adopted === root.connectedState) {
            if (SurfaceManager.ownerId === ownerId)
                SurfaceManager.close(ownerId);
            return;
        }
        root.connectedState = adopted;
    }

    function discardConnectedForNewOwner(): void {
        if (!root.connectedSurfacePresented)
            return;
        root.connectedState = RightPillState.connectedClear(root.connectedState,
            root.connectedOwnerId, root.connectedGeneration);
    }

    function toggleApp(screenName: string, edge: string, appId: string, appName: string): bool {
        const context = root.takeInvocationContext(screenName);
        const screen = context.screen;
        const invoker = context.invoker;
        const routedScreen = ScreenRouter.screenForName(screen?.name || screenName);
        const owner = root.systemTrayOwnerFor(routedScreen, "app");
        const source = "app:" + appId + ":" + appName;
        if (root.active && root.ownerScreenName === screenName
                && root.activeEdge === edge && root.menuSource === source)
            return root.close();
        if (owner && SurfaceManager.ownerId === owner)
            return SurfaceManager.close(owner);
        if (root.presentedStyle === "classic" && !invoker)
            return false;
        if (!SystemTrayService.prepareAppMenu(appId, appName))
            return false;
        return root.openPrepared(screenName, edge, "app", source, screen, invoker);
    }

    function toggleInput(screenName: string, edge: string): bool {
        const context = root.takeInvocationContext(screenName);
        const screen = context.screen;
        const invoker = context.invoker;
        const routedScreen = ScreenRouter.screenForName(screen?.name || screenName);
        const owner = root.systemTrayOwnerFor(routedScreen, "input");
        if (root.active && root.ownerScreenName === screenName
                && root.activeEdge === edge && root.menuSource === "input")
            return root.close();
        if (owner && SurfaceManager.ownerId === owner)
            return SurfaceManager.close(owner);
        if (root.presentedStyle === "classic" && !invoker)
            return false;
        if (!SystemTrayService.prepareInputMenu())
            return false;
        return root.openPrepared(screenName, edge, "input", "input", screen, invoker);
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
        if (!root.connectedSurfaceActive
                || SurfaceManager.ownerId !== root.connectedOwnerId
                || SurfaceManager.descriptor?.barConnected !== true)
            return false;
        const ownerId = root.connectedOwnerId;
        const generation = root.connectedGeneration;
        const requested = RightPillState.connectedRequestClose(
            root.connectedState, ownerId, generation);
        if (requested === root.connectedState)
            return false;
        root.connectedState = requested;
        root.returnConnectedFocus(ownerId, generation, false);
        if (Motion.reduced)
            root.finishConnectedClose(ownerId, generation);
        return true;
    }

    function toggleConnectedSurface(ownerId: string): bool {
        if (!ownerId || SurfaceManager.ownerId !== ownerId
                || SurfaceManager.descriptor?.barConnected !== true
                || root.connectedOwnerId !== ownerId)
            return false;
        if (root.connectedClosing) {
            root.adoptConnectedSurface(ownerId, SurfaceManager.descriptor,
                SurfaceManager.screen);
            return root.connectedSurfaceActive && root.connectedOwnerId === ownerId;
        }
        return root.closeConnectedSurface();
    }

    function returnConnectedFocus(ownerId: string, generation: int,
            managerReleased: bool): bool {
        if (!RightPillState.canReturnConnectedFocus(root.connectedState,
                ownerId, generation, SurfaceManager.ownerId,
                SurfaceManager.active, managerReleased))
            return false;
        const invoker = root.connectedDescriptor?.invoker || null;
        if (!invoker || !invoker.forceActiveFocus)
            return false;
        invoker.forceActiveFocus(Qt.PopupFocusReason);
        root.connectedState = RightPillState.connectedMarkFocusReturned(
            root.connectedState, ownerId, generation);
        return true;
    }

    function forceCloseConnectedSurface(): bool {
        if (!root.connectedSurfacePresented)
            return false;
        const ownerId = root.connectedOwnerId;
        const generation = root.connectedGeneration;
        const previousState = root.connectedState;
        root.connectedState = RightPillState.connectedClear(previousState,
            ownerId, generation);
        if (root.connectedState === previousState)
            return false;
        if (SurfaceManager.ownerId === ownerId
                && SurfaceManager.descriptor?.barConnected === true)
            SurfaceManager.close(ownerId);
        return true;
    }

    function releaseConnectedSurface(ownerId: string, generation: int,
            descriptor: var, screen: var): bool {
        if (!RightPillState.matchesConnectedSnapshot(root.connectedState,
                ownerId, generation, descriptor, screen))
            return false;
        const managerDescriptor = SurfaceManager.descriptor;
        const managerOwnsSnapshot = SurfaceManager.matches(
            ownerId, managerDescriptor, screen)
            && managerDescriptor?.barConnected === true;
        const previousState = root.connectedState;
        root.connectedState = RightPillState.connectedClear(
            previousState, ownerId, generation);
        if (root.connectedState === previousState)
            return false;
        if (managerOwnsSnapshot)
            SurfaceManager.closeOwned(ownerId, managerDescriptor, screen);
        return true;
    }

    function finishConnectedClose(ownerId: string, generation: int): bool {
        if (!root.connectedClosing || root.connectedOwnerId !== ownerId
                || root.connectedState.closingGeneration !== generation)
            return false;
        const closingState = root.connectedState;
        if (SurfaceManager.ownerId === ownerId
                && SurfaceManager.descriptor?.barConnected === true)
            SurfaceManager.close(ownerId);
        if (root.connectedState !== closingState)
            return false;
        root.connectedState = RightPillState.connectedFinishClose(
            closingState, ownerId, generation);
        return root.connectedState !== closingState;
    }

    function finishClose(screenName: string): void {
        if (!screenName || root.exitingScreenName !== screenName || root.active)
            return;
        root.exitingScreenName = "";
        root.exitingEdge = "";
        root.menuSource = "";
        SystemTrayService.resetPopupNavigation();
    }

    function closeForStyleChange(): void {
        const ownerId = SurfaceManager.ownerId;
        const descriptor = SurfaceManager.descriptor;
        const screen = SurfaceManager.screen;
        const menuScreenName = root.ownerScreenName || root.exitingScreenName;
        root.invocationScreen = null;
        root.invocationInvoker = null;
        root.forceCloseConnectedSurface();
        if (ownerId && RightPillState.matchesSurfaceOpen(
                SurfaceManager.ownerId, SurfaceManager.descriptor,
                SurfaceManager.screen, ownerId, descriptor, screen))
            SurfaceManager.close(ownerId);
        if (CenterSurfaceController.active)
            CenterSurfaceController.dispatch({ type: "request-mode", mode: "compact" });
        if (root.active)
            root.close();
        if (menuScreenName)
            root.finishClose(menuScreenName);
    }

    Behavior on transitionProgress {
        NumberAnimation {
            duration: Motion.reduced ? 0 : (root.presentationActive ? 240 : 190)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
            onFinished: {
                if (root.connectedClosing)
                    root.finishConnectedClose(root.connectedOwnerId,
                        root.connectedState.closingGeneration);
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

    property Connections preferenceConnection: Connections {
        target: Preferences

        function onBarStyleChanged(): void {
            root.presentedStyle = BarPopupRouting.styleAfterCleanup(
                root.presentedStyle, Preferences.barStyle,
                () => root.closeForStyleChange());
        }
    }


    property Connections surfaceConnection: Connections {
        target: SurfaceManager

        function onOpened(ownerId: string, descriptor: var, screen: var): void {
            if (!RightPillState.matchesSurfaceOpen(SurfaceManager.ownerId,
                    SurfaceManager.descriptor, SurfaceManager.screen,
                    ownerId, descriptor, screen))
                return;
            if (descriptor?.barConnected === true)
                root.adoptConnectedSurface(ownerId, descriptor, screen);
            else
                root.discardConnectedForNewOwner();
        }

        function onClosed(ownerId: string): void {
            if (SurfaceManager.active)
                return;
            if (!root.connectedSurfacePresented || root.connectedOwnerId !== ownerId
                    || root.connectedClosing)
                return;
            const generation = root.connectedGeneration;
            root.connectedState = RightPillState.connectedRequestClose(
                root.connectedState, ownerId, generation);
            root.returnConnectedFocus(ownerId, generation, true);
            if (Motion.reduced)
                root.finishConnectedClose(ownerId, generation);
        }
    }
}
