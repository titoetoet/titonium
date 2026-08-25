pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Titonium.Foundation
import Titonium.Surfaces

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
            SurfaceCoordinator.close();
        }
    }

    Component.onCompleted: Logger.info("app", "Configuration Loaded")
}
