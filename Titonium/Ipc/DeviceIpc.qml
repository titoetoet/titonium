pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Titonium.Core.Screens
import qs.Titonium.Core.Surfaces
import qs.Titonium.Overlays.Audio
import qs.Titonium.Overlays.Bluetooth
import qs.Titonium.Overlays.Network
import qs.Titonium.Osd.Audio
import qs.Titonium.Services.Audio
import qs.Titonium.Services.Bluetooth
import qs.Titonium.Services.Dock
import qs.Titonium.Services.Hyprland
import qs.Titonium.Services.Network
import qs.Titonium.Services.Notifications
import qs.Titonium.Services.WindowSwitcher

QtObject {
    property IpcHandler audioHandler: IpcHandler {
        id: audioIpc
        target: "audio"
        function state(): string {
            return "ready=" + AudioService.ready
                + ";output=" + AudioService.outputAvailable
                + ";volume=" + Math.round(AudioService.outputVolume * 100)
                + ";muted=" + AudioService.outputMuted
                + ";input=" + AudioService.inputAvailable
                + ";outputs=" + AudioService.outputDevices.length
                + ";streams=" + AudioService.playbackStreams.length;
        }
        function popup(): string {
            const screen = ScreenRouter.screenForName(HyprlandService.focusedMonitorName);
            if (!screen)
                return "unavailable:no-screen";
            return AudioPopupCoordinator.open(screen) ? audioIpc.popupState() : "unavailable:no-screen";
        }
        function closePopup(): string { AudioPopupCoordinator.close(); return "closed"; }
        function popupState(): string {
            if (!AudioPopupCoordinator.active)
                return "closed";
            return "open:" + (SurfaceManager.screen?.name || "");
        }
        function osdState(): string {
            return AudioOsdCoordinator.active
                ? "active:" + AudioOsdCoordinator.ownerScreenName : "idle";
        }
    }

    property IpcHandler dockHandler: IpcHandler {
        target: "dock"
        function state(): string { return DockService.snapshot(); }
    }

    property IpcHandler bluetoothHandler: IpcHandler {
        id: bluetoothIpc
        target: "bluetooth"
        function state(): string { return BluetoothService.snapshot(); }
        function popup(): string {
            const screen = ScreenRouter.screenForName(HyprlandService.focusedMonitorName);
            if (!screen)
                return "unavailable:no-screen";
            return BluetoothPopupCoordinator.openForIpc(screen)
                ? bluetoothIpc.popupState() : "unavailable:no-screen";
        }
        function closePopup(): string { BluetoothPopupCoordinator.close(); return "closed"; }
        function popupState(): string {
            if (!BluetoothPopupCoordinator.active)
                return "closed";
            return "open:" + (SurfaceManager.screen?.name || "");
        }
    }

    property IpcHandler networkHandler: IpcHandler {
        id: networkIpc
        target: "network"
        function state(): string { return NetworkService.snapshot(); }
        function popup(): string {
            const screen = ScreenRouter.screenForName(HyprlandService.focusedMonitorName);
            if (!screen)
                return "unavailable:no-screen";
            return NetworkPopupCoordinator.openForIpc(screen)
                ? networkIpc.popupState() : "unavailable:no-screen";
        }
        function closePopup(): string { NetworkPopupCoordinator.close(); return "closed"; }
        function popupState(): string {
            if (!NetworkPopupCoordinator.active)
                return "closed";
            return "open:" + (SurfaceManager.screen?.name || "");
        }
    }

    property IpcHandler notificationHandler: IpcHandler {
        target: "notifications"
        function state(): string {
            return JSON.stringify({
                descriptorCount: NotificationService.notifications.length,
                toastCount: NotificationService.toastNotifications.length,
                unreadCount: NotificationService.unreadCount,
            });
        }
        function markRead(): string {
            NotificationService.markAllRead();
            return String(NotificationService.unreadCount);
        }
    }

    property IpcHandler windowSwitcherHandler: IpcHandler {
        id: windowSwitcherIpc
        target: "window-switcher"
        function next(): string { WindowSwitcherService.next(); return windowSwitcherIpc.state(); }
        function previous(): string { WindowSwitcherService.previous(); return windowSwitcherIpc.state(); }
        function accept(): string { WindowSwitcherService.accept(); return windowSwitcherIpc.state(); }
        function close(): string { WindowSwitcherService.cancel(); return "closed"; }
        function state(): string { return WindowSwitcherService.snapshot(); }
    }
}
