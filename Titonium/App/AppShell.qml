pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Titonium.Foundation
import qs.Titonium.Surfaces

Scope {
    id: root

    MenuBarHost {}
    OverlayHost {}

    IpcHandler {
        target: "app"

        function status(): string {
            return ConfigStore.ready ? "ready" : "not-ready";
        }

        function reloadConfig(): void {
            ConfigStore.initialize();
        }

        function closeTransient(): void {
            if (SurfaceCoordinator.ownerId === "design-gallery" && ConfigStore.previewActive)
                ConfigStore.cancel();
            SurfaceCoordinator.close("");
        }
    }

    IpcHandler {
        target: "config"

        function beginPreview(): void {
            ConfigStore.beginPreview();
        }

        function apply(): bool {
            return ConfigStore.apply();
        }

        function cancel(): void {
            ConfigStore.cancel();
        }

        function restoreAppearance(): bool {
            return ConfigStore.restoreAppearance();
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle(screenName: string): string {
            const targetScreen = ScreenRouter.screenForName(screenName);
            if (!targetScreen)
                return "unavailable:no-screen";
            const ownerId = "calendar:" + targetScreen.name;
            if (SurfaceCoordinator.ownerId === ownerId) {
                SurfaceCoordinator.close(ownerId);
                return "closed";
            }
            SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/MenuBar/Clock/CalendarPanel.qml"),
                "keyboardFocus": "exclusive",
                "ownerId": ownerId
            }, targetScreen);
            return "open:" + targetScreen.name;
        }

        function close(): string {
            if (SurfaceCoordinator.ownerId.indexOf("calendar:") === 0)
                SurfaceCoordinator.close(SurfaceCoordinator.ownerId);
            return "closed";
        }

        function state(): string {
            return SurfaceCoordinator.ownerId.indexOf("calendar:") === 0 ? SurfaceCoordinator.ownerId : "closed";
        }
    }

    IpcHandler {
        target: "gallery"

        function toggle(screenName: string): string {
            if (SurfaceCoordinator.ownerId === "design-gallery") {
                if (ConfigStore.previewActive)
                    ConfigStore.cancel();
                SurfaceCoordinator.close("design-gallery");
                return "closed";
            }
            const targetScreen = ScreenRouter.screenForName(screenName);
            if (!targetScreen)
                return "unavailable:no-screen";
            ConfigStore.beginPreview();
            SurfaceCoordinator.open("design-gallery", {
                "source": Qt.resolvedUrl("../Design/Gallery/DesignGallery.qml"),
                "keyboardFocus": "exclusive"
            }, targetScreen);
            return "open:" + targetScreen.name;
        }

        function close(): string {
            if (ConfigStore.previewActive)
                ConfigStore.cancel();
            SurfaceCoordinator.close("design-gallery");
            return "closed";
        }

        function state(): string {
            return SurfaceCoordinator.ownerId === "design-gallery" ? "open" : "closed";
        }

        function previewMode(mode: string): bool {
            if (SurfaceCoordinator.ownerId !== "design-gallery")
                return false;
            if (mode !== "dark" && mode !== "light")
                return false;
            return ConfigStore.patch("appearance.mode", mode);
        }
    }

    Component.onCompleted: {
        if (ConfigStore.ready)
            Logger.info("app", "Configuration Loaded");
        else
            Logger.error("app", "Configuration failed: " + ConfigStore.lastError);
    }
}
