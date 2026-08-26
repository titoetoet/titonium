pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.Titonium.Core.Runtime

Singleton {
    id: root
    readonly property var trayItems: SystemTray.items.values || []
    readonly property var item: {
        for (let index = 0; index < root.trayItems.length; index++) {
            const candidate = root.trayItems[index];
            if (!candidate) continue;
            const identity = [candidate.id, candidate.title, candidate.tooltipTitle]
                .join(" ").toLowerCase();
            if (identity.includes("fcitx")) return candidate;
        }
        return null;
    }
    readonly property bool available: root.item !== null
    readonly property string iconName: root.available ? (root.item.icon || "") : ""
    readonly property string title: root.available
        ? (root.item.tooltipTitle || root.item.title || "Fcitx") : ""
    readonly property string description: root.available
        ? (root.item.tooltipDescription || "") : ""
    readonly property string engineToken: [root.iconName, root.title, root.description]
        .join(" ").trim().toLowerCase()
    readonly property bool vietnamese: ["lotus", "unikey", "bamboo", "vietnam", "vi-vn"]
        .some(fragment => root.engineToken.includes(fragment))
    readonly property bool english: ["keyboard-us", "english", "en-us", "xkb:us"]
        .some(fragment => root.engineToken.includes(fragment))
    readonly property string shortLabel: root.vietnamese ? "VI" : (root.english ? "EN" : "IM")
    readonly property string displayName: root.available && root.title.length > 0
        ? root.title : I18n.tr("menubar.input_method.unavailable")
}
