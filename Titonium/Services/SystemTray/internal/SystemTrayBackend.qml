pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../SystemTrayRules.js" as SystemTrayRules

Scope {
    id: root

    property string selectedAppId: ""
    property string selectedAppName: ""
    property string popupTitle: ""
    property bool popupIsInputMethod: false
    readonly property bool popupPrepared: internal.popupCurrentMenu !== null

    readonly property var records: SystemTrayRules.projectRecords(
        (SystemTray.items.values || []).map(item => ({
            "id": item?.id || "",
            "title": item?.title || "",
            "tooltipTitle": item?.tooltipTitle || "",
            "tooltipDescription": item?.tooltipDescription || "",
            "icon": item?.icon || "",
            "hasMenu": item?.hasMenu === true
        })))
    readonly property var selectedRecord: SystemTrayRules.selectRecord(
        root.selectedAppId, root.selectedAppName, root.records)
    readonly property var contextMenuEntries: SystemTrayRules.projectMenuEntries(
        (contextMenuOpener.children.values || []).map(entry => ({
            "text": entry?.text || "",
            "icon": entry?.icon || "",
            "enabled": entry?.enabled === true,
            "isSeparator": entry?.isSeparator === true,
            "hasChildren": entry?.hasChildren === true,
            "buttonType": entry?.buttonType === QsMenuButtonType.RadioButton
                ? "radio" : (entry?.buttonType === QsMenuButtonType.CheckBox
                    ? "checkbox" : "none"),
            "checked": entry?.checkState === Qt.Checked
        })))
    readonly property string selectedContext: SystemTrayRules.selectedContext(
        root.selectedRecord,
        root.contextMenuEntries,
        root.contextForApp(root.selectedAppId, root.selectedAppName))

    readonly property var descriptors: SystemTrayRules.project(
        (SystemTray.items.values || []).map(item => ({
            "id": item?.id || "",
            "title": item?.title || "",
            "tooltipTitle": item?.tooltipTitle || "",
            "tooltipDescription": item?.tooltipDescription || "",
            "icon": item?.icon || ""
        })))
    readonly property var inputMethod: SystemTrayRules.inputMethod(root.descriptors)
    readonly property var inputMethodRecord: SystemTrayRules.inputMethodRecord(root.records)

    readonly property var popupEntries: SystemTrayRules.projectMenuEntries(
        (popupMenuOpener.children.values || []).map(entry => ({
            "text": entry?.text || "",
            "icon": entry?.icon || "",
            "enabled": entry?.enabled === true,
            "isSeparator": entry?.isSeparator === true,
            "hasChildren": entry?.hasChildren === true,
            "buttonType": entry?.buttonType === QsMenuButtonType.RadioButton
                ? "radio" : (entry?.buttonType === QsMenuButtonType.CheckBox
                    ? "checkbox" : "none"),
            "checked": entry?.checkState === Qt.Checked
        })))
    readonly property bool popupCanGoBack: internal.popupMenuStack.length > 0

    QtObject {
        id: internal

        property var popupBaseMenu: null
        property var popupCurrentMenu: null
        property var popupMenuStack: []

        readonly property var nativeSelection: root.nativeItemForRecord(root.selectedRecord)
        readonly property var nativeInputMethod: root.nativeItemForRecord(root.inputMethodRecord)
    }

    QsMenuOpener {
        id: contextMenuOpener
        menu: internal.nativeSelection?.menu || null
    }

    QsMenuOpener {
        id: popupMenuOpener
        menu: internal.popupCurrentMenu
    }

    function contextForApp(appId: string, appName: string): string {
        return SystemTrayRules.contextForApp(appId, appName, root.descriptors);
    }

    function hasMenuForApp(appId: string, appName: string): bool {
        return root.menuRecordForApp(appId, appName) !== null;
    }

    function menuRecordForApp(appId: string, appName: string): var {
        for (let index = 0; index < root.records.length; index++) {
            const record = root.records[index];
            if (record?.inputMethod !== true
                    && SystemTrayRules.sameApplication(appId, appName, record)
                    && root.nativeItemForRecord(record)?.menu)
                return record;
        }
        return null;
    }

    function menuContextForApp(appId: string, appName: string): string {
        const record = SystemTrayRules.selectRecord(appId, appName, root.records);
        if (record && root.selectedRecord
                && record.nativeIndex === root.selectedRecord.nativeIndex)
            return root.selectedContext;
        return root.contextForApp(appId, appName);
    }

    function nativeItemForRecord(record: var): var {
        if (!record)
            return null;
        const items = SystemTray.items.values || [];
        return items[record.nativeIndex] || null;
    }

    function selectApp(appId: string, appName: string): void {
        const next = SystemTrayRules.nextMenuSelection({
            "appId": root.selectedAppId,
            "appName": root.selectedAppName
        }, appId, appName, root.records);
        root.selectedAppId = next.appId;
        root.selectedAppName = next.appName;
    }

    function prepareRecordMenu(record: var, title: string): bool {
        const nativeItem = root.nativeItemForRecord(record);
        if (!nativeItem?.menu)
            return false;
        internal.popupBaseMenu = nativeItem.menu;
        internal.popupCurrentMenu = nativeItem.menu;
        internal.popupMenuStack = [];
        root.popupTitle = title || record.tooltipTitle || record.title || record.id;
        return true;
    }

    function prepareAppMenu(appId: string, appName: string): bool {
        root.popupIsInputMethod = false;
        if (!SystemTrayRules.canOpenAppMenu(appId, appName))
            return false;
        const record = root.menuRecordForApp(appId, appName);
        if (!record)
            return false;
        root.selectApp(appId, appName);
        return root.prepareRecordMenu(record, appName);
    }

    function prepareInputMenu(): bool {
        root.popupIsInputMethod = true;
        return root.prepareRecordMenu(root.inputMethodRecord,
            root.inputMethod?.tooltipTitle || root.inputMethod?.title || "Input Method");
    }

    function enterPopupEntry(index: int): bool {
        if (SystemTrayRules.popupEntryAction(root.popupEntries, index) !== "submenu")
            return false;
        const entries = popupMenuOpener.children.values || [];
        const entry = entries[index] || null;
        if (!entry)
            return false;
        internal.popupMenuStack = internal.popupMenuStack.concat(
            [internal.popupCurrentMenu]);
        internal.popupCurrentMenu = entry;
        return true;
    }

    function triggerPopupEntry(index: int): bool {
        if (SystemTrayRules.popupEntryAction(root.popupEntries, index) !== "trigger")
            return false;
        const entries = popupMenuOpener.children.values || [];
        const entry = entries[index] || null;
        if (!entry)
            return false;
        entry.triggered();
        return true;
    }

    function popupBack(): bool {
        const stack = internal.popupMenuStack;
        if (stack.length === 0)
            return false;
        internal.popupCurrentMenu = stack[stack.length - 1];
        internal.popupMenuStack = stack.slice(0, stack.length - 1);
        return true;
    }

    function resetPopupNavigation(): void {
        internal.popupCurrentMenu = internal.popupBaseMenu;
        internal.popupMenuStack = [];
    }
}
