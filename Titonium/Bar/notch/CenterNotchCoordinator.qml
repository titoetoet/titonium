pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Center
import "CenterNotchState.js" as CenterNotchState

QtObject {
    id: root

    property string ownerScreenName: ""
    property string exitingScreenName: ""
    property string requestedPage: "overview"
    property real islandWidth: 200
    property bool focusEnabled: true
    property var selectedContext: Object.freeze({ source: "idle", id: "", title: "" })
    property real dragProgress: 0
    readonly property bool handlesAgentApproval: true
    readonly property bool active: root.ownerScreenName.length > 0
    readonly property var focusActivity: Object.freeze({
        id: "focus:daily",
        source: "focus",
        label: CenterFocusStore.text,
        icon: "center_focus_strong"
    })
    readonly property var notificationActivity:
        CenterAttentionService.presentation?.source === "notification"
            ? Object.freeze({
                id: CenterAttentionService.presentation.id || "notification:current",
                source: "notification",
                label: CenterAttentionService.presentation.title || "Notification",
                icon: CenterAttentionService.presentation.icon || "notifications"
            }) : null
    readonly property var activitySlots: CenterNotchState.activitySlots(
        CenterActivityService.activities, root.focusActivity,
        root.notificationActivity, root.focusEnabled)
    readonly property var primaryContext: CenterNotchState.contextForActivity(root.activitySlots.primary)
    readonly property var secondaryContext: CenterNotchState.contextForActivity(root.activitySlots.secondary)
    readonly property bool satelliteActive: root.activitySlots.secondary !== null
    readonly property string visualState: CenterNotchState.visualState(
        root.active, root.requestedPage, root.satelliteActive ? 1 : 0)

    function toggleFocus(): bool {
        root.focusEnabled = !root.focusEnabled;
        return root.focusEnabled;
    }

    function setCompactWidth(width: real): void {
        if (width > 0)
            root.islandWidth = width;
    }

    function open(screenName: string, pageId: string): bool {
        if (!screenName)
            return false;
        SurfaceManager.close("");
        root.exitingScreenName = "";
        root.requestedPage = CenterNotchState.normalizePage(pageId);
        root.ownerScreenName = screenName;
        return true;
    }

    function openBanner(screenName: string, context: var): bool {
        autoDismissTimer.stop();
        root.selectedContext = CenterNotchState.normalizeContext(
            context && typeof context === "object" ? context : root.primaryContext);
        root.dragProgress = 0;
        return root.open(screenName, "banner");
    }

    function openAgentApproval(screenName: string, context: var): bool {
        autoDismissTimer.stop();
        root.selectedContext = CenterNotchState.normalizeContext(
            context && typeof context === "object" ? context : {
                source: "agent", id: "", title: ""
            });
        root.dragProgress = 0;
        return root.open(screenName, CenterNotchState.entryPage("agent"));
    }

    function openAutoNotification(screenName: string, descriptor: var): bool {
        if (!CenterNotchState.shouldAutoOpen(root.visualState,
                "notification", descriptor?.urgency))
            return false;
        const opened = root.openBanner(screenName, {
            source: "notification",
            id: descriptor?.id || "",
            title: descriptor?.summary || descriptor?.body || "Notification",
            urgency: descriptor?.urgency || 0
        });
        if (opened)
            autoDismissTimer.restart();
        return opened;
    }

    function openExpanded(screenName: string): bool {
        autoDismissTimer.stop();
        if (!root.selectedContext || root.selectedContext.source === "idle")
            root.selectedContext = CenterNotchState.normalizeContext(root.primaryContext);
        root.dragProgress = 0;
        return root.open(screenName, "overview");
    }

    function selectActivity(activityId: string): bool {
        const slots = [root.activitySlots.primary, root.activitySlots.secondary];
        for (let index = 0; index < slots.length; index++) {
            if (slots[index] && slots[index].id === activityId) {
                root.selectedContext = CenterNotchState.contextForActivity(slots[index]);
                return true;
            }
        }
        return false;
    }

    function setDragProgress(value: real): void {
        root.dragProgress = Math.max(0, Math.min(1, Number(value) || 0));
    }

    function finishDrag(offset: real, velocity: real): var {
        return CenterNotchState.dragSettlePlan(root.dragProgress, offset, velocity);
    }

    function completeDragSettle(targetState: string): void {
        if (targetState === "expanded")
            root.requestedPage = "overview";
        root.dragProgress = 0;
    }

    function collapse(): bool {
        autoDismissTimer.stop();
        return root.close();
    }

    function requestPage(pageId: string): bool {
        if (!root.active)
            return false;
        root.requestedPage = CenterNotchState.normalizePage(pageId);
        return true;
    }

    function close(): bool {
        autoDismissTimer.stop();
        root.exitingScreenName = root.ownerScreenName;
        root.ownerScreenName = "";
        return true;
    }

    property Timer autoDismissTimer: Timer {
        interval: 4000
        repeat: false
        onTriggered: {
            if (root.visualState === "banner"
                    && root.selectedContext?.source === "notification")
                root.collapse();
        }
    }

    function finishClose(screenName: string): void {
        if (root.exitingScreenName === screenName) {
            root.exitingScreenName = "";
            root.requestedPage = "overview";
            root.selectedContext = Object.freeze({ source: "idle", id: "", title: "" });
            root.dragProgress = 0;
        }
    }
}
