pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.notch
import qs.Titonium.Bar.right
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Screens
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Hyprland
import qs.Titonium.Services.Mpris
import qs.Titonium.Settings
import "../Settings/SettingsLifecycleRules.js" as SettingsLifecycleRules

QtObject {
    id: root

    function openSpotlight(scope: string, query: string, stateMode: string, requestedScreen: var): string {
        if (!SettingsLifecycleRules.canYield(SettingsCoordinator.active, Preferences.savePending)
                || !SettingsCoordinator.forceCancelAndClose())
            return "unavailable:busy";
        CenterNotchCoordinator.close();
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
        CenterNotchCoordinator.close();
        RightPillCoordinator.close();
        const opened = SettingsCoordinator.open(screen.name, pageId);
        return opened ? "open:" + screen.name + ";page="
            + SettingsCoordinator.requestedPage : "unavailable:busy";
    }

    function activateCenterSource(requestedScreen: var, intent: string): string {
        if (intent === "raise-media" && MprisService.raiseSource())
            return "raised:media";
        if (intent === "open-clipboard")
            return root.openSpotlight("clipboard", "", "clipboard", requestedScreen);
        if (intent === "open-notifications")
            return root.openCenterNotch(requestedScreen, "notifications");
        return root.openCenterNotch(requestedScreen, "overview");
    }

    function openCenterNotch(requestedScreen: var, pageId: string): string {
        const screen = ScreenRouter.screenForName(requestedScreen?.name
            || HyprlandService.focusedMonitorName);
        if (!screen)
            return "unavailable:no-screen";
        if (!SettingsLifecycleRules.canYield(SettingsCoordinator.active, Preferences.savePending)
                || !SettingsCoordinator.forceCancelAndClose())
            return "unavailable:busy";
        SurfaceManager.close("");
        RightPillCoordinator.close();
        const opened = pageId === "banner"
            ? CenterNotchCoordinator.openBanner(screen.name,
                CenterNotchCoordinator.primaryContext)
            : CenterNotchCoordinator.openExpanded(screen.name);
        return opened ? "open:" + screen.name + ";page="
            + CenterNotchCoordinator.requestedPage + ";state="
            + CenterNotchCoordinator.visualState : "unavailable:no-screen";
    }

    function openCenterBanner(requestedScreen: var, context: var, autoDismiss: bool): string {
        const screen = ScreenRouter.screenForName(requestedScreen?.name
            || HyprlandService.focusedMonitorName);
        if (!screen)
            return "unavailable:no-screen";
        if (!SettingsLifecycleRules.canYield(SettingsCoordinator.active, Preferences.savePending)
                || !SettingsCoordinator.forceCancelAndClose())
            return "unavailable:busy";
        SurfaceManager.close("");
        RightPillCoordinator.close();
        const opened = autoDismiss
            ? CenterNotchCoordinator.openAutoNotification(screen.name, context)
            : CenterNotchCoordinator.openBanner(screen.name, context);
        return opened ? "open:" + screen.name + ";page=banner;state="
            + CenterNotchCoordinator.visualState : "unavailable:policy";
    }

    property Connections surfaceConnection: Connections {
        target: SurfaceManager

        function onOpened(ownerId: string, descriptor: var, screen: var): void {
            if (ownerId.length > 0) {
                if (!SettingsCoordinator.forceCancelAndClose()) {
                    SurfaceManager.close(ownerId);
                    return;
                }
                CenterNotchCoordinator.close();
                RightPillCoordinator.close();
            }
        }
    }

    property Connections centerConnection: Connections {
        target: CenterNotchCoordinator

        function onActiveChanged(): void {
            if (CenterNotchCoordinator.active) {
                RightPillCoordinator.close();
                if (!SettingsCoordinator.forceCancelAndClose())
                    CenterNotchCoordinator.close();
            }
        }
    }

    property Connections rightPillConnection: Connections {
        target: RightPillCoordinator

        function onActiveChanged(): void {
            if (!RightPillCoordinator.active)
                return;
            SurfaceManager.close("");
            CenterNotchCoordinator.close();
            if (!SettingsCoordinator.forceCancelAndClose())
                RightPillCoordinator.close();
        }
    }
}
