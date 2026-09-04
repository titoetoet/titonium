pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import "SettingsCatalog.js" as SettingsCatalog

QtObject {
    id: root

    property string ownerScreenName: ""
    property string requestedPage: "general"
    property bool discardConfirmationVisible: false
    readonly property bool active: root.ownerScreenName.length > 0

    function open(screenName: string, pageId: string): bool {
        if (!screenName || !Preferences.beginPreview())
            return false;
        root.ownerScreenName = screenName;
        root.requestedPage = SettingsCatalog.normalizePage(pageId);
        root.discardConfirmationVisible = false;
        return true;
    }

    function requestPage(pageId: string): bool {
        if (!root.active || Preferences.savePending)
            return false;
        root.requestedPage = SettingsCatalog.normalizePage(pageId);
        root.discardConfirmationVisible = false;
        return true;
    }

    function requestClose(): bool {
        if (!root.active || Preferences.savePending)
            return false;
        if (Preferences.dirty) {
            root.discardConfirmationVisible = true;
            return false;
        }
        return root.forceCancelAndClose();
    }

    function discardAndClose(): bool {
        if (Preferences.savePending)
            return false;
        Preferences.cancel();
        root.ownerScreenName = "";
        root.requestedPage = "general";
        root.discardConfirmationVisible = false;
        return true;
    }

    function forceCancelAndClose(): bool {
        return root.discardAndClose();
    }

    function closeForSessionLock(): bool {
        if (!Preferences.savePending)
            Preferences.cancel();
        root.ownerScreenName = "";
        root.requestedPage = "general";
        root.discardConfirmationVisible = false;
        return true;
    }

    function apply(): bool {
        if (!root.active || Preferences.savePending)
            return false;
        root.discardConfirmationVisible = false;
        return Preferences.apply();
    }
}
