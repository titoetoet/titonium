pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Appearance

QtObject {
    id: root
    Component.onCompleted: Qt.callLater(() => { if (Preferences.ready) root.recoverAppearance(Preferences.committedState.appearance); })
    property Connections preferencesConnection: Connections {
        target: Preferences
        function onCommittedStateChanged(): void { root.queueCommittedWallpaper(); }
        function onPreviewActiveChanged(): void { if (!Preferences.previewActive) root.queueCommittedWallpaper(); }
        function onReadyChanged(): void {
            if (Preferences.ready && !root.appearanceRecoveryReady) root.recoverAppearance(Preferences.committedState.appearance);
        }
    }
    property bool followPending: true
    property string lastFollowSignature: ""
    property string runningFollowSignature: ""
    property Connections appearanceConnection: Connections {
        target: AppearanceService
        function onSystemModeChanged(): void { root.queueCommittedWallpaper(); }
        function onTrialCandidateChanged(): void { if (!AppearanceService.trialCandidate) root.queueCommittedWallpaper(); }
    }
    property Connections screenConnection: Connections {
        target: Quickshell
        function onScreensChanged(): void {
            if (Quickshell.screens.some(screen => screen.name === "DP-1")) {
                root.lastFollowSignature = "";
                root.queueCommittedWallpaper();
                if (!root.canCaptureBaseline) root.refreshAppearanceCapability();
            }
        }
    }
    function queueCommittedWallpaper(): void {
        root.followPending = true;
        Qt.callLater(root.followCommittedWallpaper);
    }
    function committedWallpaper(): var {
        const appearance = Preferences.committedState.appearance || {};
        const policy = appearance.wallpaper?.policy || "keep";
        if (policy === "keep") return null;
        const resolved = AppearanceService.resolveCandidate({appearance: appearance, reducedMotion: false});
        let path = appearance.wallpaper?.customPath || "";
        if (policy === "theme") {
            const theme = AppearanceService.themeDescriptor(resolved.themeId);
            const relative = theme?.wallpapers?.[resolved.mode] || "";
            path = relative ? decodeURIComponent(Qt.resolvedUrl("../../../" + relative).toString().replace("file://", "")) : "";
        }
        if (!path) return null;
        return {path: path, candidate: appearance, signature: JSON.stringify([policy, path])};
    }
    function followCommittedWallpaper(): void {
        if (!root.followPending || !Preferences.ready || !root.appearanceRecoveryReady
            || Preferences.previewActive || AppearanceService.trialCandidate || root.busy || root.appearanceLease || !root.canCaptureBaseline) return;
        root.followPending = false;
        const desired = root.committedWallpaper();
        if (!desired) { root.lastFollowSignature = ""; return; }
        if (desired.signature === root.lastFollowSignature) return;
        root.runningFollowSignature = desired.signature;
        root.appearanceLease = true;
        root.start("appearance-follow", {screen: "DP-1", path: desired.path, candidate: desired.candidate});
    }
    onBusyChanged: { if (!root.busy && root.followPending) Qt.callLater(root.followCommittedWallpaper); }

    property bool appearanceLease: true
    property bool appearanceRecoveryReady: false
    property bool managedWallpaper: false
    property int recoveryRetries: 0
    // Hyprpaper and Quickshell may start concurrently at login. Retry only this
    // bounded startup window for an explicitly configured managed wallpaper.
    property Timer recoveryRetry: Timer {
        interval: 500
        onTriggered: {
            if (root.canCaptureBaseline || (root.appearanceLease && root.appearanceRecoveryReady)) return;
            if (root.busy) { start(); return; }
            root.recoveryRetries += 1;
            root.recoverAppearance(Preferences.committedState.appearance);
        }
    }
    property bool canCaptureBaseline: false
    readonly property bool appearanceAvailable: canCaptureBaseline
    property string appearanceCapabilityError: ""
    property var baselineSnapshot: ({})
    property string lastError: ""
    property int appearanceGeneration: -1
    signal appearanceFinished(int generation, bool success, string error)
    signal appearanceSavingReady(int generation, bool success, string error)
    signal appearanceRolledBack(int generation, bool success, string error)
    signal appearanceCommitted(int generation, bool success, string error)
    signal appearanceRecovered(bool success, string error)

    function beginAppearance(screenName: string, path: string, generation: int, candidateAppearance: var, targetFit: var): bool {
        if (root.busy || root.appearanceLease || !root.appearanceRecoveryReady) return false;
        recoveryRetry.stop();
        root.appearanceGeneration = generation;
        root.appearanceLease = true;
        root.start("appearance-begin", {screen: screenName, path: path, generation: generation, candidate: candidateAppearance, fit: targetFit === undefined ? "cover" : targetFit});
        return true;
    }
    function appearanceAction(action: string, generation: int): bool {
        if (root.busy || !root.appearanceLease || root.appearanceGeneration !== generation) return false;
        root.start(action, {generation: generation});
        return true;
    }
    function markAppearanceSaving(generation: int): bool { return root.appearanceAction("appearance-saving", generation); }
    function rollbackAppearance(generation: int): bool { return root.appearanceAction("appearance-rollback", generation); }
    function commitAppearance(generation: int): bool { return root.appearanceAction("appearance-commit", generation); }
    function refreshAppearanceCapability(): bool {
        if (root.busy) return false;
        if (root.appearanceLease && !root.appearanceRecoveryReady)
            return root.recoverAppearance(Preferences.committedState.appearance);
        if (root.appearanceLease) return false;
        if (root.managedWallpaper) return root.recoverAppearance(Preferences.committedState.appearance);
        root.start("appearance-probe", {});
        return true;
    }
    function recoverAppearance(persistedAppearance: var): bool {
        if (root.busy) return false;
        root.appearanceLease = true;
        root.start("appearance-recover", {persisted: persistedAppearance});
        return true;
    }

    property var consumers: []
    readonly property bool active: root.consumers.length > 0
    readonly property bool busy: worker.running || root.operation !== ""
    property var items: []
    property string directory: ""
    property bool available: false
    property bool truncated: false
    property string statusKey: ""
    property var applied: ({})
    property string operation: ""
    property bool refreshPending: false
    property bool discardCatalog: false

    // Leases keep one view's teardown from deactivating another visible consumer.
    function setVisible(consumer: var, visible: bool): void {
        const next = root.consumers.filter(item => item !== consumer);
        if (visible) next.push(consumer);
        root.consumers = next;
    }

    onActiveChanged: {
        if (root.active) root.refresh(root.directory);
        else {
            root.refreshPending = false;
            if (root.operation === "catalog") {
                root.discardCatalog = true;
                worker.running = false;
            }
            root.items = [];
        }
    }

    function start(action: string, payload: var): void {
        root.operation = action;
        root.discardCatalog = false;
        root.statusKey = "wallpapers.busy";
        worker.command = ["python3", Quickshell.shellPath("Titonium/Services/Wallpapers/wallpapers.py"),
            action, JSON.stringify(payload)];
        worker.running = true;
    }

    function refresh(path: string): void {
        if (!root.active) return;
        if (!root.appearanceRecoveryReady) {
            root.refreshPending = true;
            if (Preferences.ready && !root.busy) root.recoverAppearance(Preferences.committedState.appearance);
            return;
        }
        if (root.busy) {
            root.refreshPending = true;
            return;
        }
        root.items = [];
        root.available = false;
        root.start("catalog", {directory: path});
    }

    function applyTo(screenName: string, path: string): void {
        if (root.appearanceLease) { root.statusKey = "wallpapers.error.locked"; return; }
        if (!root.active || root.busy) return;
        if (!/^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$/.test(screenName)) {
            root.statusKey = "wallpapers.error.screen";
            return;
        }
        if (!root.items.some(item => item.path === path)) {
            root.statusKey = "wallpapers.error.image";
            return;
        }
        root.start("apply", {screen: screenName, path: path, directory: root.directory});
    }

    function finishAppearance(exitCode: int, response: string): void {
            let result = {ok: false, error: "request", lease: true};
            try { result = JSON.parse(response); } catch (_) {}
            const success = exitCode === 0 && result.ok === true;
            const error = success ? "" : (result.error || "request");
            const action = root.operation;
            const generation = root.appearanceGeneration;
            root.operation = "";
            root.appearanceLease = result.lease !== false;
            root.lastError = error;
            if (result.managed !== undefined) root.managedWallpaper = result.managed === true;
            if (result.snapshot) root.baselineSnapshot = Object.freeze(result.snapshot);
            if (result.canCaptureBaseline !== undefined) {
                root.canCaptureBaseline = result.canCaptureBaseline === true;
                root.appearanceCapabilityError = result.capabilityError || "";
            }
            if (action === "appearance-begin") {
                root.canCaptureBaseline = success;
                if (error) root.appearanceCapabilityError = error;
            }
            root.statusKey = success ? "wallpapers.applied" : "wallpapers.error." + error;
            if (result.screen && result.path) {
                const next = Object.assign({}, root.applied); next[result.screen] = result.path; root.applied = next;
            }
            if (action === "appearance-follow") {
                if (success) root.lastFollowSignature = root.runningFollowSignature;
                else if (root.appearanceLease) root.appearanceRecoveryReady = false;
            }
            if (success && (action === "appearance-recover" || action === "appearance-probe")) root.queueCommittedWallpaper();
            if (success && action === "appearance-commit") {
                const desired = root.committedWallpaper();
                if (desired && desired.path === result.path) root.lastFollowSignature = desired.signature;
            }
            if (action === "appearance-recover") {
                root.appearanceRecoveryReady = success;
                recoveryRetry.stop();
                const daemonPending = success
                    ? root.managedWallpaper && !root.canCaptureBaseline && root.appearanceCapabilityError === "unavailable"
                    : error === "unavailable";
                if (daemonPending && root.recoveryRetries < 10)
                    recoveryRetry.start();
                root.appearanceRecovered(success, error);
            } else if (action === "appearance-begin") root.appearanceFinished(generation, success, error);
            else if (action === "appearance-saving") root.appearanceSavingReady(generation, success, error);
            else if (action === "appearance-rollback") root.appearanceRolledBack(generation, success, error);
            else if (action === "appearance-commit") root.appearanceCommitted(generation, success, error);
            if (root.refreshPending && root.active) { root.refreshPending = false; Qt.callLater(() => root.refresh(root.directory)); }
    }

    function finish(exitCode: int): void {
        if (root.operation.indexOf("appearance-") === 0) {
            const response = output.text;
            Qt.callLater(() => root.finishAppearance(exitCode, response));
            return;
        }
        if (!(root.operation === "catalog" && (root.discardCatalog || !root.active))) {
            try {
                const result = JSON.parse(output.text);
                if (exitCode !== 0 || !result.ok) {
                    const code = ["directory", "image", "screen", "backend", "unavailable", "timeout", "request", "locked", "persistence"].indexOf(result.error) >= 0
                        ? result.error : "request";
                    root.statusKey = "wallpapers.error." + code;
                } else if (root.operation === "catalog") {
                    root.directory = result.directory;
                    root.items = result.items.map(item => Object.freeze(item));
                    root.available = result.available;
                    root.truncated = result.truncated;
                    root.statusKey = !root.available ? "wallpapers.error.unavailable"
                        : (root.items.length ? "wallpapers.select" : "wallpapers.empty");
                } else {
                    const next = Object.assign({}, root.applied);
                    next[result.screen] = result.path;
                    root.applied = next;
                    root.statusKey = result.warning ? "wallpapers.error.persistence" : "wallpapers.applied";
                }
            } catch (_) {
                root.statusKey = "wallpapers.error.request";
            }
        }
        root.operation = "";
        if (root.refreshPending && root.active) {
            root.refreshPending = false;
            Qt.callLater(() => root.refresh(root.directory));
        }
    }

    property Process worker: Process {
        id: worker
        stdout: StdioCollector { id: output }
        stderr: StdioCollector {}
        onExited: exitCode => root.finish(exitCode)
    }
}
