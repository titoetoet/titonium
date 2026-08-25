pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Titonium.Foundation
import qs.Titonium.Modules.Frame
import qs.Titonium.Platform
import qs.Titonium.Surfaces

Scope {
    id: root

    MenuBarHost {}
    FrameHost {}
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

        function appearanceState(): string {
            return JSON.stringify(ConfigStore.previewState.appearance || {});
        }

        function settingsDocument(): string {
            return JSON.stringify(ConfigStore.previewState || {});
        }

        function committedSettingsDocument(): string {
            return JSON.stringify(ConfigStore.committedState || {});
        }

        function previewTheme(themeId: string): bool {
            if (!ThemeCatalog.entryFor(themeId))
                return false;
            return ConfigStore.patch("appearance.themeId", themeId);
        }

        function previewMaterialBackend(backend: string): bool {
            if (["auto", "qml", "solid", "native"].indexOf(backend) < 0)
                return false;
            return ConfigStore.patch("appearance.overrides.material.defaultBackend", backend);
        }

        function materialState(): string {
            const policy = ConfigStore.themeState.material || {};
            const allowed = policy.allowedBackends || ["solid"];
            const requested = policy.defaultBackend || "solid";
            let resolved = requested;
            if (requested === "auto")
                resolved = policy.compositorIntegration && Capabilities.nativeGlassAvailable
                    && allowed.indexOf("native") >= 0 ? "native" : (allowed.indexOf("qml") >= 0 ? "qml" : "solid");
            else if (requested === "native" && !Capabilities.nativeGlassAvailable)
                resolved = allowed.indexOf("qml") >= 0 ? "qml" : "solid";
            return JSON.stringify({
                "themeId": ConfigStore.themeState.id || ThemeCatalog.defaultThemeId,
                "requested": requested,
                "resolved": resolved,
                "nativeAvailable": Capabilities.nativeGlassAvailable,
                "nativeProbe": Capabilities.hyprglassDetail
            });
        }

        function layoutDocument(): string {
            return JSON.stringify(ConfigStore.previewLayout || {});
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(screenName: string): string {
            const targetScreen = ScreenRouter.screenForName(screenName);
            if (!targetScreen)
                return "unavailable:no-screen";
            const ownerId = "settings:" + targetScreen.name;
            if (SurfaceCoordinator.ownerId === ownerId) {
                SurfaceCoordinator.close(ownerId);
                return "closed:cancelled";
            }
            ConfigStore.beginPreview();
            SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/Settings/SettingsCenter.qml"),
                "keyboardFocus": "exclusive",
                "ownerId": ownerId,
                "cancelPreviewOnClose": true
            }, targetScreen);
            return "open:" + targetScreen.name;
        }

        function close(): string {
            if (SurfaceCoordinator.ownerId.indexOf("settings:") === 0)
                SurfaceCoordinator.close(SurfaceCoordinator.ownerId);
            return "closed:cancelled";
        }

        function state(): string {
            if (SurfaceCoordinator.ownerId.indexOf("settings:") !== 0)
                return "closed";
            return SurfaceCoordinator.ownerId + (ConfigStore.previewActive ? ":preview" : "");
        }

        function openPage(page: string, screenName: string): string {
            const availablePages = ["theme", "typography", "layout", "frame", "audio", "system", "launcher", "material"];
            if (availablePages.indexOf(page) < 0)
                return "unavailable:unknown-page";
            if (page === "material" && ConfigStore.themeState.id === "titonium-neutral")
                return "unavailable:incompatible-theme";
            const targetScreen = ScreenRouter.screenForName(screenName);
            if (!targetScreen)
                return "unavailable:no-screen";
            const ownerId = "settings:" + targetScreen.name;
            if (SurfaceCoordinator.ownerId !== ownerId)
                ConfigStore.beginPreview();
            SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/Settings/SettingsCenter.qml"),
                "keyboardFocus": "exclusive",
                "ownerId": ownerId,
                "page": page,
                "cancelPreviewOnClose": true
            }, targetScreen);
            return "open:" + page + ":" + targetScreen.name;
        }

        function previewMode(mode: string): bool {
            if (SurfaceCoordinator.ownerId.indexOf("settings:") !== 0)
                return false;
            if (mode !== "dark" && mode !== "light")
                return false;
            return ConfigStore.patch("appearance.mode", mode);
        }

        function previewBodySize(size: int): bool {
            if (SurfaceCoordinator.ownerId.indexOf("settings:") !== 0 || size < 11 || size > 18)
                return false;
            return ConfigStore.patch("appearance.overrides.typography.bodySize", size);
        }

        function previewBarHeight(height: int): bool {
            if (SurfaceCoordinator.ownerId.indexOf("settings:") !== 0 || height < 32 || height > 52)
                return false;
            return ConfigStore.patchLayout("menubar.height", height);
        }

        function previewFrame(enabled: bool): bool {
            if (SurfaceCoordinator.ownerId.indexOf("settings:") !== 0)
                return false;
            return ConfigStore.patch("modules.frame.enabled", enabled);
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(screenName: string): string {
            const targetScreen = ScreenRouter.screenForName(screenName);
            if (!targetScreen)
                return "unavailable:no-screen";
            const ownerId = "launcher:" + targetScreen.name;
            if (SurfaceCoordinator.ownerId === ownerId) {
                SurfaceCoordinator.close(ownerId);
                return "closed";
            }
            SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/MenuBar/Launcher/ArchMenu.qml"),
                "keyboardFocus": "exclusive",
                "closeOnMonitorChange": true,
                "cancelPreviewOnClose": true,
                "ownerId": ownerId
            }, targetScreen);
            return "open:" + targetScreen.name;
        }

        function close(): string {
            if (SurfaceCoordinator.ownerId.indexOf("launcher:") === 0)
                SurfaceCoordinator.close(SurfaceCoordinator.ownerId);
            return "closed";
        }

        function section(screenName: string, sectionId: string): string {
            const targetScreen = ScreenRouter.screenForName(screenName);
            if (!targetScreen)
                return "unavailable:no-screen";
            const ownerId = "launcher:" + targetScreen.name;
            SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/MenuBar/Launcher/ArchMenu.qml"),
                "keyboardFocus": "exclusive",
                "closeOnMonitorChange": true,
                "cancelPreviewOnClose": true,
                "ownerId": ownerId,
                "section": sectionId
            }, targetScreen);
            return "open:" + targetScreen.name + ":" + sectionId;
        }

        function state(): string {
            return SurfaceCoordinator.ownerId.indexOf("launcher:") === 0 ? SurfaceCoordinator.ownerId : "closed";
        }
    }

    IpcHandler {
        target: "clock"

        function toggle(screenName: string): string {
            const targetScreen = ScreenRouter.screenForName(screenName);
            if (!targetScreen)
                return "unavailable:no-screen";
            const ownerId = "clock:" + targetScreen.name;
            if (SurfaceCoordinator.ownerId === ownerId) {
                SurfaceCoordinator.close(ownerId);
                return "closed";
            }
            SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/MenuBar/Clock/AnalogClockPanel.qml"),
                "keyboardFocus": "exclusive",
                "ownerId": ownerId
            }, targetScreen);
            return "open:" + targetScreen.name;
        }

        function close(): string {
            if (SurfaceCoordinator.ownerId.indexOf("clock:") === 0)
                SurfaceCoordinator.close(SurfaceCoordinator.ownerId);
            return "closed";
        }

        function state(): string {
            return SurfaceCoordinator.ownerId.indexOf("clock:") === 0
                ? SurfaceCoordinator.ownerId : "closed";
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
                "keyboardFocus": "exclusive",
                "cancelPreviewOnClose": true
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
