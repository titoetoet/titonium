pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Appearance
import qs.Titonium.Services.Wallpapers
import "AppearanceTransaction.js" as Transaction
import "../Services/Appearance/AppearanceRules.js" as AppearanceRules

QtObject {
    id: root
    property string screenName: ""
    property bool sessionOpen: false
    property var base: Transaction.pick(Preferences.effectiveState)
    property var candidate: Transaction.clone(root.base)
    property bool advancedOpen: false
    property string editMode: "dark"
    property string phase: "idle"
    property string error: ""
    property int generation: 0
    property var trialState: null
    property double now: Date.now()
    property bool wallpaperHeld: false
    property bool cancelRequested: false
    property bool closing: false
    property string intent: ""
    property var saveBefore: null
    property var saveAfter: null
    property bool saveMotionOwned: false
    property var undoRecord: null
    property bool undoing: false
    property bool motionTouched: false
    property bool finalizationPending: false
    property var saveWallpaperBaseline: null
    property var undoWallpaperTarget: null
    readonly property var tokens: AppearanceService.resolveCandidate(root.candidate)
    readonly property bool themeWallpaperMissing: !root.undoWallpaperTarget
        && root.candidate.appearance?.wallpaper?.policy === "theme"
        && !AppearanceService.themeDescriptor(root.tokens.themeId)?.wallpapers?.[root.tokens.mode]
    readonly property bool dirty: !Transaction.same(root.candidate, root.base)
    readonly property bool trialActive: root.phase === "trial"
    readonly property bool busy: root.phase !== "idle" && root.phase !== "trial" && root.phase !== "kept"
    readonly property int remainingSeconds: root.trialState ? Math.max(0,
        Math.ceil((root.trialState.deadline - root.now) / 1000)) : 0
    readonly property bool canUndo: !!root.undoRecord && !root.dirty && !Preferences.dirty
        && !Preferences.savePending && !root.busy && !root.trialActive && !root.finalizationPending

    function open(screen: string): void {
        if (root.sessionOpen) return;
        root.screenName = screen;
        root.sessionOpen = true;
        root.closing = false;
        root.base = Transaction.pick(Preferences.effectiveState);
        root.candidate = Transaction.clone(root.base);
        root.editMode = root.tokens.mode;
        if (!root.finalizationPending) root.error = "";
        root.motionTouched = false;
    }
    function close(): void {
        root.closing = true;
        root.cancelRequested = true;
        if (!root.finalizationPending) root.cancelTrial();
        if (!root.busy) root.finishClose();
    }
    function finishClose(): void {
        root.sessionOpen = false;
        if (!Preferences.savePending) Preferences.cancel();
        root.screenName = "";
        root.advancedOpen = false;
        root.base = Transaction.pick(Preferences.committedState);
        root.candidate = Transaction.clone(root.base);
        root.closing = false;
        root.cancelRequested = false;
    }
    function editable(): bool {
        return root.sessionOpen && !root.busy && !root.trialActive && !Preferences.savePending && !root.finalizationPending;
    }
    function updateCandidate(next: var): bool {
        if (!root.editable()) return false;
        root.candidate = {appearance:AppearanceRules.normalize(next.appearance, {}), reducedMotion:next.reducedMotion === true};
        root.undoing = false;
        root.undoWallpaperTarget = null;
        root.error = "";
        if (root.wallpaperHeld) root.rollback();
        return true;
    }
    function selectTheme(id: string): void {
        if (!AppearanceService.catalog.some(item => item.id === id)) return;
        const next = Transaction.clone(root.candidate); next.appearance.themeId = id;
        root.updateCandidate(next);
    }
    function setMode(mode: string): void {
        if (["dark","light","system"].indexOf(mode) < 0) return;
        const next = Transaction.clone(root.candidate); next.appearance.mode = mode;
        if (root.updateCandidate(next)) root.editMode = root.tokens.mode;
    }
    function setOverride(key: string, value: var): void {
        root.updateCandidate(Transaction.override(root.candidate, root.editMode, key, value));
    }
    function restoreDefaults(includeAppearance: bool): bool {
        const next = Transaction.clone(root.candidate);
        if (includeAppearance)
            next.appearance = Transaction.clone(Preferences.shippedDefaults.appearance);
        next.reducedMotion = Preferences.shippedDefaults.accessibility.reducedMotion === true;
        if (!root.updateCandidate(next)) return false;
        root.motionTouched = true;
        root.editMode = root.tokens.mode;
        return true;
    }
    function resetOverride(key: string): void { root.setOverride(key, null); }
    function resetThemeOverrides(): void {
        const next = Transaction.clone(root.candidate);
        if (next.appearance.themeOverrides) delete next.appearance.themeOverrides[next.appearance.themeId];
        root.updateCandidate(next);
    }
    function setReducedMotion(value: bool): void {
        const next = Transaction.clone(root.candidate); next.reducedMotion = value;
        if (root.updateCandidate(next)) root.motionTouched = true;
    }
    function setWallpaper(policy: string, path: string): void {
        if (["keep","theme","custom"].indexOf(policy) < 0) return;
        const next = Transaction.clone(root.candidate);
        next.appearance.wallpaper = {policy: policy, customPath: path};
        root.updateCandidate(next);
    }
    function setAdvancedOpen(value: bool): void {
        root.advancedOpen = value;
        if (value) root.editMode = root.tokens.mode;
    }
    function wallpaperPath(): string {
        if (root.undoWallpaperTarget) return root.undoWallpaperTarget.path || "";
        const wp = root.candidate.appearance.wallpaper || {};
        if (wp.policy === "custom") return wp.customPath || "";
        if (wp.policy !== "theme") return "";
        const theme = AppearanceService.themeDescriptor(root.tokens.themeId);
        const relative = theme?.wallpapers?.[root.tokens.mode] || "";
        if (!relative) return "";
        return decodeURIComponent(Qt.resolvedUrl("../../" + relative).toString().replace("file://", ""));
    }
    function wantsWallpaper(): bool {
        return !!root.undoWallpaperTarget || (root.candidate.appearance.wallpaper?.policy || "keep") !== "keep";
    }
    function startTrial(): bool {
        if (!root.editable()) return false;
        if (root.themeWallpaperMissing) { root.error = "settings.appearance.no_style_wallpaper"; return false; }
        root.error = ""; root.cancelRequested = false; root.intent = "trial";
        if (root.wallpaperHeld) { root.enterTrial(); return true; }
        root.generation += 1;
        if (root.wantsWallpaper()) {
            const path = root.wallpaperPath();
            if (!path) { root.error = "wallpapers.error.image"; return false; }
            root.phase = "preparing";
            if (!WallpapersService.beginAppearance(root.screenName, path, root.generation, root.candidate.appearance)) {
                root.phase = "idle"; root.error = "wallpapers.error." + (WallpapersService.lastError || "unavailable"); return false;
            }
        } else root.enterTrial();
        return true;
    }
    function enterTrial(): void {
        root.now = Date.now();
        root.trialState = Transaction.trial(root.generation, root.now, root.candidate);
        AppearanceService.setTrial(root.candidate, root.generation);
        root.phase = "trial";
    }
    function keepTrial(): bool {
        if (!root.trialActive || !root.stageCandidate()) return false;
        AppearanceService.clearTrial(root.generation);
        root.trialState = null;
        root.phase = root.wallpaperHeld ? "kept" : "idle";
        return true;
    }
    function cancelTrial(): void {
        if (root.finalizationPending) return;
        root.cancelRequested = true;
        if (root.phase === "preparing" || root.phase === "marking" || root.phase === "saving" || root.phase === "committing") return;
        AppearanceService.clearTrial(root.generation);
        root.trialState = null;
        if (root.wallpaperHeld) root.rollback();
        else if (root.phase !== "rollback") root.phase = "idle";
    }
    function rollback(): void {
        root.phase = "rollback";
        if (!WallpapersService.rollbackAppearance(root.generation)) {
            root.error = "wallpapers.error." + (WallpapersService.lastError || "request");
            root.phase = "kept";
        }
    }
    function stageCandidate(): bool {
        if (!Preferences.stageAppearance(root.candidate, root.base)) return false;
        root.base = Transaction.clone(root.candidate);
        return true;
    }
    function apply(): bool {
        if (!root.editable()) return false;
        if (root.themeWallpaperMissing) { root.error = "settings.appearance.no_style_wallpaper"; return false; }
        root.error = ""; root.cancelRequested = false; root.intent = "apply";
        if (!root.wallpaperHeld) root.saveWallpaperBaseline = null;
        root.saveBefore = Transaction.clone(Preferences.committedState);
        root.saveMotionOwned = root.motionTouched;
        if (!root.stageCandidate() || !Preferences.dirty) return false;
        root.saveAfter = Transaction.clone(Preferences.effectiveState);
        if (root.wallpaperHeld) return root.markSaving();
        // Unchanged appearance must not re-apply wallpaper when saving another Settings page.
        if (root.wantsWallpaper() && (root.undoWallpaperTarget || !Transaction.same(root.saveBefore.appearance, root.saveAfter.appearance))) {
            root.generation += 1;
            const path = root.wallpaperPath();
            if (!path) { root.error = "wallpapers.error.image"; return false; }
            root.phase = "preparing";
            if (!WallpapersService.beginAppearance(root.screenName,path,root.generation,root.candidate.appearance,root.undoWallpaperTarget?.fit || "cover")) {
                root.phase = "idle"; root.error = "wallpapers.error." + (WallpapersService.lastError || "unavailable"); return false;
            }
            return true;
        }
        return root.save();
    }
    function markSaving(): bool {
        root.phase = "marking";
        if (!WallpapersService.markAppearanceSaving(root.generation)) {
            root.error = "wallpapers.error." + (WallpapersService.lastError || "request");
            root.rollback(); return false;
        }
        return true;
    }
    function save(): bool {
        root.phase = "saving";
        if (!Preferences.apply()) {
            root.error = "settings.appearance.error.save";
            if (root.wallpaperHeld) root.rollback(); else root.phase = "idle";
            return false;
        }
        return true;
    }
    function finishApply(): void {
        root.error = "";
        if (root.undoing) root.undoRecord = null;
        else if (root.saveBefore && (!Transaction.same(root.saveBefore.appearance,root.saveAfter.appearance) || root.saveMotionOwned))
            root.undoRecord = {before:root.saveBefore,after:root.saveAfter,motionOwned:root.saveMotionOwned,wallpaperBaseline:root.saveWallpaperBaseline};
        else root.undoRecord = null;
        root.undoing = false;
        root.motionTouched = false;
        root.undoWallpaperTarget = null;
        root.saveWallpaperBaseline = null;
        root.finalizationPending = false;
        root.base = Transaction.pick(Preferences.committedState);
        root.candidate = Transaction.clone(root.base);
        root.phase = "idle";
        root.wallpaperHeld = false;
        if (root.closing) root.finishClose();
    }
    function undoLastApply(): bool {
        if (!root.canUndo) return false;
        const restored = Transaction.restoreAppearance(Preferences.committedState,
            root.undoRecord.before,root.undoRecord.after,root.undoRecord.motionOwned);
        root.candidate = Transaction.pick(restored);
        root.motionTouched = root.undoRecord.motionOwned;
        root.undoWallpaperTarget = root.undoRecord.wallpaperBaseline;
        root.undoing = true;
        if (root.apply()) return true;
        return false;
    }
    function retryFinalization(): bool {
        if (!root.finalizationPending || root.busy) return false;
        root.phase = "committing";
        if (WallpapersService.commitAppearance(root.generation)) return true;
        root.phase = "idle";
        return false;
    }
    function finalizationFailed(): void {
        root.error = "settings.appearance.error.finalize";
        root.finalizationPending = true;
        root.phase = "idle";
        if (root.closing) root.finishClose();
    }
    property Timer trialClock: Timer {
        interval: 100; repeat: true; running: root.trialActive
        onTriggered: {
            root.now = Date.now();
            if (Transaction.expired(root.trialState,root.now,root.generation)) root.cancelTrial();
        }
    }
    property Connections preferenceEvents: Connections {
        target: Preferences
        function onEffectiveStateChanged(): void {
            if (!root.sessionOpen || root.busy || root.trialActive) return;
            const current = Preferences.effectiveState.accessibility?.reducedMotion === true;
            if (root.candidate.reducedMotion === root.base.reducedMotion && current !== root.base.reducedMotion) {
                const next = Transaction.clone(root.candidate); next.reducedMotion = current;
                const nextBase = Transaction.clone(root.base); nextBase.reducedMotion = current;
                root.base = nextBase; root.candidate = next;
            }
        }
        function onApplyFinished(success: bool): void {
            if (root.phase !== "saving") return;
            if (!success) {
                root.error = "settings.appearance.error.save";
                if (root.wallpaperHeld) root.rollback();
                else { root.phase = "idle"; if (root.closing) root.finishClose(); }
                return;
            }
            if (root.wallpaperHeld) {
                root.phase = "committing";
                if (!WallpapersService.commitAppearance(root.generation)) {
                    root.finalizationFailed();
                }
            } else root.finishApply();
        }
    }
    property Connections wallpaperEvents: Connections {
        target: WallpapersService
        function onAppearanceFinished(g: int, success: bool, failure: string): void {
            if (g !== root.generation) return;
            if (!success) {
                root.error = "wallpapers.error." + (failure || "request");
                root.wallpaperHeld = WallpapersService.appearanceLease;
                if (root.wallpaperHeld) root.rollback();
                else { root.phase = "idle"; if (root.closing) root.finishClose(); }
                return;
            }
            root.wallpaperHeld = true;
            root.saveWallpaperBaseline = Transaction.clone(WallpapersService.baselineSnapshot);
            if (root.cancelRequested || root.closing) root.rollback();
            else if (root.intent === "trial") root.enterTrial();
            else root.markSaving();
        }
        function onAppearanceSavingReady(g: int, success: bool, failure: string): void {
            if (g !== root.generation) return;
            if (!success || root.cancelRequested || root.closing) {
                if (!success) root.error = "wallpapers.error." + (failure || "persistence");
                root.rollback(); return;
            }
            root.save();
        }
        function onAppearanceRolledBack(g: int, success: bool, failure: string): void {
            if (g !== root.generation) return;
            AppearanceService.clearTrial(root.generation);
            root.trialState = null;
            if (success) {
                root.wallpaperHeld = false; root.saveWallpaperBaseline = null; root.phase = "idle";
                if (root.closing) root.finishClose();
            } else {
                root.error = "wallpapers.error." + (failure || "backend"); root.phase = "kept";
            }
        }
        function onAppearanceCommitted(g: int, success: bool, failure: string): void {
            if (g !== root.generation) return;
            if (success) root.finishApply();
            else root.finalizationFailed();
        }
    }
}
