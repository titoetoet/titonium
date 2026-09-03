pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import "SystemTrayRules.js" as SystemTrayRules
import "internal" as Internal

QtObject {
    id: root

    readonly property var descriptors: Internal.SystemTrayBackend.descriptors
    readonly property var inputMethod: Internal.SystemTrayBackend.inputMethod
    readonly property var popupEntries: Internal.SystemTrayBackend.popupEntries
    readonly property bool popupCanGoBack: Internal.SystemTrayBackend.popupCanGoBack
    readonly property string popupTitle: Internal.SystemTrayBackend.popupTitle
    readonly property bool popupIsInputMethod: Internal.SystemTrayBackend.popupIsInputMethod
    readonly property bool popupPrepared: Internal.SystemTrayBackend.popupPrepared

    function inputMenuIcon(label: string): string {
        return SystemTrayRules.inputMenuIcon(label);
    }

    function inputMenuPresentation(entry: var): var {
        return SystemTrayRules.inputMenuPresentation(entry);
    }

    function contextForApp(appId: string, appName: string): string {
        return SystemTrayRules.contextForApp(appId, appName, root.descriptors);
    }

    function hasMenuForApp(appId: string, appName: string): bool {
        return Internal.SystemTrayBackend.hasMenuForApp(appId, appName);
    }

    function menuContextForApp(appId: string, appName: string): string {
        return Internal.SystemTrayBackend.menuContextForApp(appId, appName);
    }

    function selectApp(appId: string, appName: string): void {
        Internal.SystemTrayBackend.selectApp(appId, appName);
    }

    function prepareAppMenu(appId: string, appName: string): bool {
        return Internal.SystemTrayBackend.prepareAppMenu(appId, appName);
    }

    function prepareInputMenu(): bool {
        return Internal.SystemTrayBackend.prepareInputMenu();
    }

    function enterPopupEntry(index: int): bool {
        return Internal.SystemTrayBackend.enterPopupEntry(index);
    }

    function triggerPopupEntry(index: int): bool {
        return Internal.SystemTrayBackend.triggerPopupEntry(index);
    }

    function popupBack(): bool {
        return Internal.SystemTrayBackend.popupBack();
    }

    function resetPopupNavigation(): void {
        Internal.SystemTrayBackend.resetPopupNavigation();
    }
}
