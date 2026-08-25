pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Titonium.Foundation
import qs.Titonium.Modules.Frame
import qs.Titonium.Platform
import qs.Titonium.Platform.Hyprland
import qs.Titonium.Surfaces

Scope {
    id: root

    readonly property var clipboardHistory: ClipboardHistoryStore

    function coordinatorIpcResult(accepted: bool, successResult: string): string {
        if (!accepted && SurfaceCoordinator.ownerGuarded)
            return "blocked:guarded:" + SurfaceCoordinator.ownerId;
        return successResult;
    }

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
                const closed = SurfaceCoordinator.close(ownerId);
                return root.coordinatorIpcResult(closed, "closed:cancelled");
            }
            ConfigStore.beginPreview();
            const opened = SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/Settings/SettingsCenter.qml"),
                "keyboardFocus": "exclusive",
                "ownerId": ownerId,
                "cancelPreviewOnClose": true
            }, targetScreen);
            return root.coordinatorIpcResult(opened, "open:" + targetScreen.name);
        }

        function close(): string {
            if (SurfaceCoordinator.ownerId.indexOf("settings:") === 0) {
                const closed = SurfaceCoordinator.close(SurfaceCoordinator.ownerId);
                return root.coordinatorIpcResult(closed, "closed:cancelled");
            }
            return "closed:cancelled";
        }

        function state(): string {
            if (SurfaceCoordinator.ownerId.indexOf("settings:") !== 0)
                return "closed";
            return SurfaceCoordinator.ownerId + (ConfigStore.previewActive ? ":preview" : "");
        }

        function openPage(page: string, screenName: string): string {
            const availablePages = ["theme", "typography", "layout", "frame", "audio", "system", "spotlight", "material"];
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
            const opened = SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/Settings/SettingsCenter.qml"),
                "keyboardFocus": "exclusive",
                "ownerId": ownerId,
                "page": page,
                "cancelPreviewOnClose": true
            }, targetScreen);
            return root.coordinatorIpcResult(opened, "open:" + page + ":" + targetScreen.name);
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
        target: "arch-menu"

        function toggle(screenName: string): string {
            const targetScreen = ScreenRouter.screenForName(screenName);
            if (!targetScreen)
                return "unavailable:no-screen";
            const ownerId = "arch-menu:" + targetScreen.name;
            if (SurfaceCoordinator.ownerId === ownerId) {
                const closed = SurfaceCoordinator.close(ownerId);
                return root.coordinatorIpcResult(closed, "closed");
            }
            const opened = SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/MenuBar/ArchMenu/ArchMenu.qml"),
                "keyboardFocus": "exclusive",
                "closeOnMonitorChange": true,
                "ownerId": ownerId
            }, targetScreen);
            return root.coordinatorIpcResult(opened, "open:" + targetScreen.name);
        }

        function close(): string {
            if (SurfaceCoordinator.ownerId.indexOf("arch-menu:") === 0) {
                const closed = SurfaceCoordinator.close(SurfaceCoordinator.ownerId);
                return root.coordinatorIpcResult(closed, "closed");
            }
            return "closed";
        }

        function state(): string {
            return SurfaceCoordinator.ownerId.indexOf("arch-menu:") === 0
                ? SurfaceCoordinator.ownerId : "closed";
        }
    }

    IpcHandler {
        id: spotlightIpc
        target: "spotlight"

        function toggle(): string {
            const targetScreen = ScreenRouter.screenForName(HyprlandAdapter.focusedMonitorName);
            if (!targetScreen)
                return "unavailable:no-screen";
            const ownerId = "spotlight:" + targetScreen.name;
            if (SurfaceCoordinator.ownerId === ownerId) {
                const closed = SurfaceCoordinator.close(ownerId);
                return root.coordinatorIpcResult(closed, "closed");
            }
            const opened = SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/Spotlight/SpotlightSurface.qml"),
                "keyboardFocus": "exclusive",
                "closeOnMonitorChange": true,
                "ownerId": ownerId,
                "mode": "applications",
                "query": "",
                "stateMode": "browse",
                "selectedIndex": 0
            }, targetScreen);
            return root.coordinatorIpcResult(opened, "open:applications:" + targetScreen.name);
        }

        function clipboard(): string {
            const targetScreen = ScreenRouter.screenForName(HyprlandAdapter.focusedMonitorName);
            if (!targetScreen)
                return "unavailable:no-screen";
            const ownerId = "spotlight:" + targetScreen.name;
            const opened = SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/Spotlight/SpotlightSurface.qml"),
                "keyboardFocus": "exclusive",
                "closeOnMonitorChange": true,
                "ownerId": ownerId,
                "mode": "clipboard",
                "query": "",
                "stateMode": "clipboard",
                "selectedIndex": 0
            }, targetScreen);
            return root.coordinatorIpcResult(opened, "open:clipboard:" + targetScreen.name);
        }

        function close(): string {
            if (SurfaceCoordinator.ownerId.indexOf("spotlight:") === 0) {
                const closed = SurfaceCoordinator.close(SurfaceCoordinator.ownerId);
                return root.coordinatorIpcResult(closed, "closed");
            }
            return "closed";
        }

        function state(): string {
            if (SurfaceCoordinator.ownerId.indexOf("spotlight:") !== 0)
                return "closed";
            const screenName = SurfaceCoordinator.screen?.name || "";
            const descriptor = SurfaceCoordinator.descriptor || {};
            return "open:" + (descriptor.mode || "applications") + ":" + screenName
                + ";mode=" + (descriptor.stateMode || "browse")
                + ";query=" + (descriptor.query || "")
                + ";selected=" + (descriptor.selectedIndex || 0);
        }

        function setQuery(query: string): string {
            if (SurfaceCoordinator.ownerId.indexOf("spotlight:") !== 0)
                return "unavailable:closed";
            const ownerId = SurfaceCoordinator.ownerId;
            const descriptorMode = SurfaceCoordinator.descriptor?.mode || "applications";
            const opened = SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/Spotlight/SpotlightSurface.qml"),
                "keyboardFocus": "exclusive",
                "closeOnMonitorChange": true,
                "ownerId": ownerId,
                "mode": descriptorMode,
                "query": query,
                "stateMode": descriptorMode === "clipboard" ? "clipboard"
                    : (query.trim().length > 0 ? "results" : "browse"),
                "selectedIndex": 0
            }, SurfaceCoordinator.screen);
            return root.coordinatorIpcResult(opened, spotlightIpc.state());
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
                const closed = SurfaceCoordinator.close(ownerId);
                return root.coordinatorIpcResult(closed, "closed");
            }
            const opened = SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/MenuBar/Clock/AnalogClockPanel.qml"),
                "keyboardFocus": "exclusive",
                "ownerId": ownerId
            }, targetScreen);
            return root.coordinatorIpcResult(opened, "open:" + targetScreen.name);
        }

        function close(): string {
            if (SurfaceCoordinator.ownerId.indexOf("clock:") === 0) {
                const closed = SurfaceCoordinator.close(SurfaceCoordinator.ownerId);
                return root.coordinatorIpcResult(closed, "closed");
            }
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
                const closed = SurfaceCoordinator.close(ownerId);
                return root.coordinatorIpcResult(closed, "closed");
            }
            const opened = SurfaceCoordinator.open(ownerId, {
                "source": Qt.resolvedUrl("../Modules/MenuBar/Clock/CalendarPanel.qml"),
                "keyboardFocus": "exclusive",
                "ownerId": ownerId
            }, targetScreen);
            return root.coordinatorIpcResult(opened, "open:" + targetScreen.name);
        }

        function close(): string {
            if (SurfaceCoordinator.ownerId.indexOf("calendar:") === 0) {
                const closed = SurfaceCoordinator.close(SurfaceCoordinator.ownerId);
                return root.coordinatorIpcResult(closed, "closed");
            }
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
                const closed = SurfaceCoordinator.close("design-gallery");
                return root.coordinatorIpcResult(closed, "closed");
            }
            const targetScreen = ScreenRouter.screenForName(screenName);
            if (!targetScreen)
                return "unavailable:no-screen";
            ConfigStore.beginPreview();
            const opened = SurfaceCoordinator.open("design-gallery", {
                "source": Qt.resolvedUrl("../Design/Gallery/DesignGallery.qml"),
                "keyboardFocus": "exclusive",
                "cancelPreviewOnClose": true
            }, targetScreen);
            return root.coordinatorIpcResult(opened, "open:" + targetScreen.name);
        }

        function close(): string {
            const closed = SurfaceCoordinator.close("design-gallery");
            return root.coordinatorIpcResult(closed, "closed");
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
