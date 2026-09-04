pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.right
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Screens
import qs.Titonium.Core.Surfaces
import qs.Titonium.Core.Surfaces.Center
import qs.Titonium.Services.Hyprland
import qs.Titonium.Settings
import "../Settings/SettingsLifecycleRules.js" as SettingsLifecycleRules

QtObject {
    id: root

    function centerScreen(requestedScreen: var): var {
        return ScreenRouter.screenForName(requestedScreen?.name
            || requestedScreen || HyprlandService.focusedMonitorName);
    }

    function acquireCenter(screen: var): bool {
        if (!screen)
            return false;
        if (!SettingsLifecycleRules.canYield(SettingsCoordinator.active, Preferences.savePending)
                || !SettingsCoordinator.forceCancelAndClose())
            return false;
        SurfaceManager.close("");
        RightPillCoordinator.close();
        CenterSurfaceController.dispatch({ type: "surface-granted", screenName: screen.name });
        return true;
    }

    function openCenter(requestedScreen: var, destination: string, contextId: string): string {
        const screen = root.centerScreen(requestedScreen);
        if (!root.acquireCenter(screen))
            return screen ? "unavailable:busy" : "unavailable:no-screen";
        if (contextId)
            CenterSurfaceController.dispatch({ type: "activate-context", contextId: contextId });
        CenterSurfaceController.dispatch({ type: "request-mode", mode: "expanded" });
        return "open:" + screen.name + ";mode=expanded";
    }

    function presentCenterBanner(requestedScreen: var, contextId: string, policy: var): string {
        const screen = root.centerScreen(requestedScreen);
        if (!root.acquireCenter(screen))
            return screen ? "unavailable:busy" : "unavailable:no-screen";
        const timeoutMs = Math.max(0, Number(policy?.timeoutMs) || 0);
        CenterSurfaceController.dispatch({
            type: "present", contextId: contextId, requestedMode: "banner",
            timeoutMs: timeoutMs, focusPolicy: policy?.focusPolicy || "none"
        });
        return "open:" + screen.name + ";mode=banner";
    }

    function closeCenter(reason: string): bool {
        return CenterSurfaceController.dispatch({ type: "request-mode", mode: "compact",
            reason: reason });
    }

    function openSpotlight(scope: string, query: string, stateMode: string, requestedScreen: var): string {
        if (!SettingsLifecycleRules.canYield(SettingsCoordinator.active, Preferences.savePending)
                || !SettingsCoordinator.forceCancelAndClose())
            return "unavailable:busy";
        root.closeCenter("spotlight-opened");
        RightPillCoordinator.close();
        const screen = ScreenRouter.screenForName(requestedScreen?.name
            || HyprlandService.focusedMonitorName);
        if (!screen)
            return "unavailable:no-screen";
        const owner = "spotlight:" + screen.name;
        const opened = SurfaceManager.open(owner, {
            "source": Qt.resolvedUrl("../Overlays/Spotlight/SpotlightSurface.qml"),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": owner,
            "mode": scope,
            "query": query,
            "stateMode": stateMode,
            "selectedIndex": 0
        }, screen);
        return opened ? "open:" + scope + ":" + screen.name : "unavailable:no-screen";
    }

    function openSettings(requestedScreen: var, pageId: string): string {
        const screen = ScreenRouter.screenForName(requestedScreen?.name
            || HyprlandService.focusedMonitorName);
        if (!screen)
            return "unavailable:no-screen";
        SurfaceManager.close("");
        root.closeCenter("settings-opened");
        RightPillCoordinator.close();
        const opened = SettingsCoordinator.open(screen.name, pageId);
        return opened ? "open:" + screen.name + ";page="
            + SettingsCoordinator.requestedPage : "unavailable:busy";
    }

    property Connections surfaceConnection: Connections {
        target: SurfaceManager

        function onOpened(ownerId: string, descriptor: var, screen: var): void {
            if (ownerId.length > 0) {
                if (!SettingsCoordinator.forceCancelAndClose()) {
                    SurfaceManager.close(ownerId);
                    return;
                }
                root.closeCenter("surface-opened");
                RightPillCoordinator.close();
            }
        }
    }

    property Connections centerConnection: Connections {
        target: CenterSurfaceController

        function onActiveChanged(): void {
            if (CenterSurfaceController.active) {
                RightPillCoordinator.close();
                if (!SettingsCoordinator.forceCancelAndClose())
                    root.closeCenter("settings-busy");
            }
        }
    }

    property Connections rightPillConnection: Connections {
        target: RightPillCoordinator

        function onActiveChanged(): void {
            if (!RightPillCoordinator.active)
                return;
            SurfaceManager.close("");
            root.closeCenter("right-pill-opened");
            if (!SettingsCoordinator.forceCancelAndClose())
                RightPillCoordinator.close();
        }
    }

    property Connections neutralCenterConnection: Connections {
        target: CenterSurfaceController

        function onSurfaceRequested(request: var): void {
            if (request.type !== "acquire-surface")
                return;
            const screen = root.centerScreen(request.screenName);
            if (!root.acquireCenter(screen)) {
                CenterSurfaceController.dispatch({ type: "surface-denied", reason: "busy" });
                return;
            }
            if (request.contextId)
                CenterSurfaceController.dispatch({ type: "activate-context",
                    contextId: request.contextId });
            if (request.mode === "banner")
                CenterSurfaceController.dispatch({ type: "present",
                    contextId: request.contextId, requestedMode: "banner",
                    timeoutMs: request.timeoutMs, focusPolicy: request.focusPolicy });
            else
                CenterSurfaceController.dispatch({ type: "request-mode", mode: request.mode });
        }
    }
}
