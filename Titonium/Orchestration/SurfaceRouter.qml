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
import "NotificationPanelRouting.js" as NotificationPanelRouting

QtObject {
    id: root

    function automaticCenterPresentationAvailable(): bool {
        return !!root.centerScreen(null)
            && !SurfaceManager.active
            && !RightPillCoordinator.active
            && !SettingsCoordinator.active
            && !Preferences.savePending;
    }

    function syncAutomaticCenterPresentation(): void {
        CenterSurfaceController.dispatch({
            type: "set-presentation-available",
            available: root.automaticCenterPresentationAvailable(),
        });
    }

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
            timeoutMs: timeoutMs, focusPolicy: policy?.focusPolicy || "none",
            presentationOwner: policy?.presentationOwner || "user",
        });
        return "open:" + screen.name + ";mode=banner";
    }

    function closeCenter(reason: string): bool {
        return CenterSurfaceController.dispatch({ type: "request-mode", mode: "compact",
            reason: reason });
    }

    function toggleNotificationPanel(requestedScreen: var, invoker: var): string {
        const screen = root.centerScreen(requestedScreen);
        if (!screen)
            return "unavailable:no-screen";
        const owner = NotificationPanelRouting.ownerId(screen.name);
        const action = NotificationPanelRouting.toggleAction(SurfaceManager.ownerId, owner);
        if (action === "close") {
            SurfaceManager.close(owner);
            return "closed:" + screen.name;
        }
        if (action === "reject")
            return "unavailable:no-screen";
        if (!SettingsLifecycleRules.canYield(SettingsCoordinator.active, Preferences.savePending)
                || !SettingsCoordinator.forceCancelAndClose())
            return "unavailable:busy";
        root.closeCenter("notifications-opened");
        RightPillCoordinator.close();
        const opened = SurfaceManager.open(owner, {
            "source": Qt.resolvedUrl("../Notifications/NotificationPanel.qml"),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": owner,
            "invoker": invoker
        }, screen);
        return opened ? "open:" + screen.name : "unavailable:no-screen";
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
            root.syncAutomaticCenterPresentation();
            if (ownerId.length > 0) {
                if (!SettingsCoordinator.forceCancelAndClose()) {
                    SurfaceManager.close(ownerId);
                    return;
                }
                root.closeCenter("surface-opened");
                RightPillCoordinator.close();
            }
        }
        function onClosed(ownerId: string): void {
            root.syncAutomaticCenterPresentation();
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
            root.syncAutomaticCenterPresentation();
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
            if (request.presentationOwner === "notification") {
                root.syncAutomaticCenterPresentation();
                if (!screen || !CenterSurfaceController.criticalPresentationEligible) {
                    CenterSurfaceController.dispatch({
                        type: "surface-denied", reason: "busy",
                    });
                    return;
                }
                if (CenterSurfaceController.ownerScreenName !== screen.name
                        || CenterSurfaceController.mode === "closed")
                    CenterSurfaceController.dispatch({
                        type: "surface-granted", screenName: screen.name,
                    });
                CenterSurfaceController.dispatch({
                    type: "activate-context", contextId: request.contextId,
                });
                CenterSurfaceController.dispatch({
                    type: "present",
                    contextId: request.contextId,
                    requestedMode: "banner",
                    timeoutMs: request.timeoutMs,
                    focusPolicy: request.focusPolicy,
                    presentationOwner: request.presentationOwner,
                });
                return;
            }
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
                    timeoutMs: request.timeoutMs, focusPolicy: request.focusPolicy,
                    presentationOwner: request.presentationOwner });
            else
                CenterSurfaceController.dispatch({ type: "request-mode", mode: request.mode });
        }
    }

    property Connections settingsConnection: Connections {
        target: SettingsCoordinator
        function onActiveChanged(): void {
            root.syncAutomaticCenterPresentation();
        }
    }

    property Connections preferencesConnection: Connections {
        target: Preferences
        function onSavePendingChanged(): void {
            root.syncAutomaticCenterPresentation();
        }
    }

    Component.onCompleted: root.syncAutomaticCenterPresentation()
}
