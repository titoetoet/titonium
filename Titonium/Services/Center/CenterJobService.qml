pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import "CenterJobRules.js" as CenterJobRules

QtObject {
    id: root

    signal notificationPublished(var notification)

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

    function syncActivity(job: var): void {
        if (!job)
            return;
        CenterActivityService.upsert({
            "id": "job:" + job.id,
            "source": "job",
            "label": job.label,
            "icon": "work",
            "importance": job.importance,
            "progress": job.percent,
            "deadline": 0,
            "updatedAt": job.changedAt
        });
    }

    function removeActivity(id: string): void {
        CenterActivityService.remove("job:" + id.trim());
    }

    function jobById(id: string): var {
        const normalizedId = id.trim();
        for (let index = 0; index < root.jobState.length; index++) {
            if (root.jobState[index].id === normalizedId)
                return root.jobState[index];
        }
        return null;
    }

    function applyResult(result: var): string {
        if (result.error)
            return result.error;
        root.jobState = result.next;
        root.syncIndicator(result.next.length > 0);
        if (result.event !== null) {
            if (result.event.kind === "job_failed"
                    || result.event.kind === "job_requires_action")
                root.notificationPublished(result.event);
            else
                CenterAttentionService.publish(result.event);
        }
        return "ok";
    }

    function start(id: string, label: string, importance: string): string {
        const result = CenterJobRules.start(
            root.jobState, id, label, importance, Date.now());
        if (result.error)
            return result.error;
        CenterAttentionService.clear("job:" + id.trim());
        const response = root.applyResult(result);
        root.syncActivity(root.jobById(id));
        return response;
    }

    function progress(id: string, percent: string, label: string): string {
        const result = CenterJobRules.progress(
            root.jobState, id, percent, label, Date.now());
        if (result.error)
            return result.error;
        const response = root.applyResult(result);
        root.syncActivity(root.jobById(id));
        return response;
    }

    function complete(id: string, summary: string): string {
        const result = CenterJobRules.complete(
            root.jobState, id, summary, Date.now());
        if (result.error)
            return result.error;
        const response = root.applyResult(result);
        root.removeActivity(id);
        return response;
    }

    function fail(id: string, summary: string): string {
        const result = CenterJobRules.fail(
            root.jobState, id, summary, Date.now());
        if (result.error)
            return result.error;
        const response = root.applyResult(result);
        root.removeActivity(id);
        return response;
    }

    function requireAction(id: string, summary: string): string {
        const result = CenterJobRules.requireAction(
            root.jobState, id, summary, Date.now());
        if (result.error)
            return result.error;
        const response = root.applyResult(result);
        root.removeActivity(id);
        return response;
    }

    function clear(id: string): string {
        const result = CenterJobRules.clear(root.jobState, id);
        const eventCleared = CenterAttentionService.clear("job:" + id.trim());
        root.removeActivity(id);
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
