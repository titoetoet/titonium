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
    }

    Component.onCompleted: {
        if (ConfigStore.ready)
            Logger.info("app", "Configuration Loaded");
        else
            Logger.error("app", "Configuration failed: " + ConfigStore.lastError);
    }
}
