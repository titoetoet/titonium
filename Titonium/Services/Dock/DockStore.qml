pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import "DockRules.js" as DockRules

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

    function togglePin(appId: string): bool {
        const id = typeof appId === "string" ? appId.trim() : "";
        if (!id)
            return false;
        const key = id.toLocaleLowerCase();
        const next = root.pinnedIds.slice();
        for (let index = 0; index < next.length; index++) {
            if (next[index].toLocaleLowerCase() !== key)
                continue;
            next.splice(index, 1);
            return root.setPinnedIds(next);
        }
        next.push(id);
        return root.setPinnedIds(next);
    }

    function movePin(fromIndex: int, toIndex: int): bool {
        return root.setPinnedIds(DockRules.movePinnedId(
            root.pinnedIds, fromIndex, toIndex));
    }

    function setPinnedOpen(value: bool): bool {
        return root.setVisibilityMode(value ? "reserve-space" : "auto-hide");
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
