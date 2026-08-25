pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Platform.Applications
import qs.Titonium.Platform.Hyprland

QtObject {
    id: root

    readonly property var sourceToplevels: HyprlandAdapter.runningToplevels
    readonly property string activeTitle: HyprlandAdapter.activeWindowTitle
    readonly property string activeClass: HyprlandAdapter.activeWindowClass
    readonly property var items: root.buildItems()

    function buildItems(): var {
        // These reads keep the binding reactive when focus changes without polling.
        const unusedActiveTitle = root.activeTitle;
        const unusedActiveClass = root.activeClass;
        const grouped = {};
        const result = [];
        for (let index = 0; index < root.sourceToplevels.length; index++) {
            const toplevel = root.sourceToplevels[index];
            const appId = (toplevel.appId || "").trim();
            const title = toplevel.title || ApplicationCatalog.nameForAppId(appId);
            const key = (appId || title).toLocaleLowerCase();
            const active = HyprlandAdapter.isToplevelActive(toplevel);
            if (!grouped[key]) {
                const item = {
                    "key": key,
                    "appId": appId,
                    "name": ApplicationCatalog.nameForAppId(appId),
                    "title": title,
                    "icon": ApplicationCatalog.iconForAppId(appId),
                    "active": active,
                    "toplevel": toplevel,
                    "windowCount": 1
                };
                grouped[key] = item;
                result.push(item);
            } else {
                const item = grouped[key];
                item.windowCount++;
                if (active) {
                    item.active = true;
                    item.title = title;
                    item.toplevel = toplevel;
                }
            }
        }
        return result;
    }

    function activate(item: var): void {
        HyprlandAdapter.activateToplevel(item?.toplevel);
    }
}
