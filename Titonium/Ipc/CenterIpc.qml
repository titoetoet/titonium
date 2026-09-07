pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Titonium.Services.Center
import qs.Titonium.Services.Mpris
import qs.Titonium.Services.SystemMonitor

QtObject {
    property IpcHandler centerHandler: IpcHandler {
        target: "center"
        function state(): string { return CenterAttentionService.snapshot(); }
        function activityState(): string { return CenterActivityService.snapshot(); }
        function focusState(): string { return CenterFocusStore.snapshot(); }
        function monitorState(): string { return SystemMonitorService.state(); }
    }

    property IpcHandler focusHandler: IpcHandler {
        target: "focus"
        function state(): string { return JSON.stringify(FocusSessionService.session); }
        function start(durationSeconds: int): bool { return FocusSessionService.start(durationSeconds); }
        function cancel(): void { FocusSessionService.cancel(); }
    }

    property IpcHandler mprisHandler: IpcHandler {
        target: "mpris"
        function state(): string { return MprisService.snapshot(); }
    }

    property IpcHandler timerHandler: IpcHandler {
        target: "timer"

        function state(): string { return CenterTimerService.snapshot(); }
        function start(id: string, durationSeconds: int, label: string): string {
            CenterTimerService.start(id, durationSeconds, label);
            return CenterTimerService.snapshot();
        }
        function cancel(id: string): string {
            CenterTimerService.cancel(id);
            return CenterTimerService.snapshot();
        }
        function acknowledge(id: string): string {
            CenterTimerService.acknowledge(id);
            return CenterTimerService.snapshot();
        }
    }

    property IpcHandler jobHandler: IpcHandler {
        target: "job"

        function state(): string { return CenterJobService.snapshot(); }
        function start(id: string, label: string, importance: string): string {
            return CenterJobService.start(id, label, importance);
        }
        function progress(id: string, percent: string, label: string): string {
            return CenterJobService.progress(id, percent, label);
        }
        function complete(id: string, summary: string): string {
            return CenterJobService.complete(id, summary);
        }
        function fail(id: string, summary: string): string {
            return CenterJobService.fail(id, summary);
        }
        function requireAction(id: string, summary: string): string {
            return CenterJobService.requireAction(id, summary);
        }
        function clear(id: string): string { return CenterJobService.clear(id); }
    }
}
