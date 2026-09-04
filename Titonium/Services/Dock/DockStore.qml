pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import "DockRules.js" as DockRules
import "DockMutationRules.js" as DockMutationRules

QtObject {
    id: root

    readonly property string visibilityMode: Preferences.dock.visibilityMode
    readonly property var pinnedIds: DockRules.uniqueIds(Preferences.dock.pinnedIds)
    readonly property var visibilityPolicy: DockRules.visibilityPolicy(root.visibilityMode)
    readonly property bool pinnedOpen: root.visibilityPolicy.pinnedOpen
    readonly property bool autoHide: root.visibilityPolicy.autoHide
    readonly property bool hidden: root.visibilityPolicy.hidden
    readonly property bool ready: Preferences.ready

    function write(path: string, value: var): bool {
        return Preferences.previewActive
            ? Preferences.patch("modules.dock." + path, value)
            : Preferences.commitPatch("modules.dock." + path, value);
    }

    function setVisibilityMode(mode: string): bool {
        const normalized = DockRules.normalizeVisibilityMode(mode);
        if (normalized !== mode)
            return false;
        return root.write("visibilityMode", normalized);
    }

    function setPinnedIds(ids: var): bool {
        return root.write("pinnedIds", DockRules.uniqueIds(ids));
    }

    function isPinned(appId: string): bool {
        const key = typeof appId === "string" ? appId.trim().toLocaleLowerCase() : "";
        if (!key)
            return false;
        return root.pinnedIds.some(id => id.toLocaleLowerCase() === key);
    }

    function togglePin(appId: string): var {
        const plan = DockMutationRules.toggle(root.pinnedIds, appId);
        if (!plan.accepted)
            return plan;
        const accepted = root.setPinnedIds(plan.value);
        return DockMutationRules.withWriteResult(plan, accepted,
            Preferences.lastError || "preferences-busy");
    }

    function movePin(fromIndex: int, toIndex: int): bool {
        return root.setPinnedIds(DockRules.movePinnedId(
            root.pinnedIds, fromIndex, toIndex));
    }

    function setPinnedOpen(value: bool): var {
        const accepted = root.setVisibilityMode(value ? "reserve-space" : "auto-hide");
        return DockMutationRules.visibility(value, accepted,
            Preferences.lastError || "preferences-busy");
    }

    function setAutoHide(value: bool): bool {
        return root.setVisibilityMode(value ? "auto-hide" : "always-visible");
    }

    function snapshot(): var {
        return {
            $schema: "titonium.dock/v1",
            schemaVersion: 1,
            pinnedIds: root.pinnedIds,
            pinnedOpen: root.pinnedOpen,
            autoHide: root.autoHide,
            visibilityMode: root.visibilityMode,
        };
    }
}
