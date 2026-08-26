pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Titonium.Bar
import qs.Titonium.Bar.notch
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Screens
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Applications
import qs.Titonium.Services.Hyprland

Scope {
    id: root

    function openSpotlight(scope: string, query: string, stateMode: string): string {
        CenterNotchCoordinator.close();
        const screen = ScreenRouter.screenForName(HyprlandService.focusedMonitorName);
        if (!screen)
            return "unavailable:no-screen";
        const owner = "spotlight:" + screen.name;
        const opened = SurfaceManager.open(owner, {
            "source": Qt.resolvedUrl("Overlays/Spotlight/SpotlightSurface.qml"),
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

    BarHost {}
    OverlayHost {}

    IpcHandler {
        target: "app"
        function status(): string { return Preferences.ready ? "ready" : "not-ready"; }
        function closeTransient(): void { SurfaceManager.close(""); }
    }

    IpcHandler {
        id: centerNotchIpc
        target: "centerNotch"

        function open(page: string): string {
            const screen = ScreenRouter.screenForName(HyprlandService.focusedMonitorName);
            if (!screen)
                return "unavailable:no-screen";
            CenterNotchCoordinator.open(screen.name, page);
            return centerNotchIpc.state();
        }

        function page(page: string): string {
            if (!CenterNotchCoordinator.requestPage(page))
                return "unavailable:closed";
            return centerNotchIpc.state();
        }

        function close(): string {
            CenterNotchCoordinator.close();
            return "closed";
        }

        function state(): string {
            if (!CenterNotchCoordinator.active)
                return "closed";
            return "open:" + CenterNotchCoordinator.ownerScreenName
                + ";page=" + CenterNotchCoordinator.requestedPage;
        }
    }

    IpcHandler {
        id: spotlightIpc
        target: "spotlight"

        function toggle(): string {
            if (SurfaceManager.ownerId.indexOf("spotlight:") === 0) {
                SurfaceManager.close(SurfaceManager.ownerId);
                return "closed";
            }
            return root.openSpotlight("applications", "", "browse");
        }

        function clipboard(): string {
            return root.openSpotlight("clipboard", "", "clipboard");
        }

        function close(): string {
            if (SurfaceManager.ownerId.indexOf("spotlight:") === 0)
                SurfaceManager.close(SurfaceManager.ownerId);
            return "closed";
        }

        function state(): string {
            if (SurfaceManager.ownerId.indexOf("spotlight:") !== 0)
                return "closed";
            const descriptor = SurfaceManager.descriptor || {};
            return "open:" + (descriptor.mode || "applications") + ":"
                + (SurfaceManager.screen?.name || "")
                + ";mode=" + (descriptor.stateMode || "browse")
                + ";query=" + (descriptor.query || "")
                + ";selected=" + (descriptor.selectedIndex || 0);
        }

        function setQuery(query: string): string {
            if (SurfaceManager.ownerId.indexOf("spotlight:") !== 0)
                return "unavailable:closed";
            const scope = SurfaceManager.descriptor?.mode || "applications";
            const mode = scope === "clipboard" ? "clipboard"
                : (scope === "system" ? "system"
                    : (query.trim().length > 0 ? "results" : "browse"));
            root.openSpotlight(scope, query, mode);
            return spotlightIpc.state();
        }

        function setScope(scope: string): string {
            if (SurfaceManager.ownerId.indexOf("spotlight:") !== 0)
                return "unavailable:closed";
            if (["applications", "clipboard", "system"].indexOf(scope) < 0)
                return "unavailable:unknown-scope";
            const query = SurfaceManager.descriptor?.query || "";
            const mode = scope === "clipboard" ? "clipboard"
                : (scope === "system" ? "system"
                    : (query.trim().length > 0 ? "results" : "browse"));
            root.openSpotlight(scope, query, mode);
            return spotlightIpc.state();
        }

        function firstVisibleApplicationId(): string {
            const applications = ApplicationService.visibleApplications;
            return applications.length > 0 ? applications[0].id : "";
        }

        function visibleApplicationCount(): int {
            return ApplicationService.visibleApplications.length;
        }
    }
}
