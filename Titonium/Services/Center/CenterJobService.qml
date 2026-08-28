pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import "CenterJobRules.js" as CenterJobRules

QtObject {
    id: root

    property var jobState: CenterJobRules.initialState()

    readonly property var jobs: root.jobState
    readonly property int activeCount: root.jobState.length

    function syncIndicator(active: bool): void {
        CenterAttentionService.setIndicator(
            "jobs",
            "work",
            I18n.tr("menubar.center.indicator.jobs"),
            active
        );
    }

    function applyResult(result: var): string {
        if (result.error)
            return result.error;
        root.jobState = result.next;
        root.syncIndicator(result.next.length > 0);
        if (result.event !== null)
            CenterAttentionService.publish(result.event);
        return "ok";
    }

    function start(id: string, label: string, importance: string): string {
        const result = CenterJobRules.start(
            root.jobState, id, label, importance, Date.now());
        if (result.error)
            return result.error;
        CenterAttentionService.clear("job:" + id.trim());
        return root.applyResult(result);
    }

    function progress(id: string, percent: string, label: string): string {
        return root.applyResult(CenterJobRules.progress(
            root.jobState, id, percent, label, Date.now()));
    }

    function complete(id: string, summary: string): string {
        return root.applyResult(CenterJobRules.complete(
            root.jobState, id, summary, Date.now()));
    }

    function fail(id: string, summary: string): string {
        return root.applyResult(CenterJobRules.fail(
            root.jobState, id, summary, Date.now()));
    }

    function requireAction(id: string, summary: string): string {
        return root.applyResult(CenterJobRules.requireAction(
            root.jobState, id, summary, Date.now()));
    }

    function clear(id: string): string {
        const result = CenterJobRules.clear(root.jobState, id);
        const eventCleared = CenterAttentionService.clear("job:" + id.trim());
        if (result.error)
            return eventCleared ? "ok" : result.error;
        root.jobState = result.next;
        root.syncIndicator(result.next.length > 0);
        return "ok";
    }

    function snapshot(): string {
        return JSON.stringify({
            activeCount: root.activeCount,
            jobs: root.jobs
        });
    }

    // App pins the explicit, session-only Job registry to shell lifetime.
    function activate(): void {}
}
