pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.notch
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
        const opened = CenterNotchCoordinator.open(screen.name, pageId);
        return opened ? "open:" + screen.name + ";page="
            + CenterNotchCoordinator.requestedPage : "unavailable:no-screen";
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
            }
        }
    }

    property Connections centerConnection: Connections {
        target: CenterNotchCoordinator

        function onActiveChanged(): void {
            if (CenterNotchCoordinator.active
                    && !SettingsCoordinator.forceCancelAndClose())
                CenterNotchCoordinator.close();
        }
    }
}
