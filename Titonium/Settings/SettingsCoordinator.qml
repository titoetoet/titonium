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
    readonly property bool busy: Preferences.savePending || AppearanceCoordinator.busy
    readonly property bool dirty: Preferences.dirty || AppearanceCoordinator.dirty
    readonly property bool active: root.ownerScreenName.length > 0

    function open(screenName: string, pageId: string): bool {
        if (!screenName || root.busy || !Preferences.beginPreview())
            return false;
        AppearanceCoordinator.open(screenName);
        root.ownerScreenName = screenName;
        root.requestedPage = SettingsCatalog.normalizePage(pageId);
        root.discardConfirmationVisible = false;
        return true;
    }

    function requestPage(pageId: string): bool {
        if (!root.active || root.busy)
            return false;
        AppearanceCoordinator.cancelTrial();
        root.requestedPage = SettingsCatalog.normalizePage(pageId);
        root.discardConfirmationVisible = false;
        return true;
    }

    function requestClose(): bool {
        if (!root.active || root.busy)
            return false;
        if (AppearanceCoordinator.trialActive) {
            AppearanceCoordinator.cancelTrial();
            return false;
        }
        if (root.dirty) {
            root.discardConfirmationVisible = true;
            return false;
        }
        return root.forceCancelAndClose();
    }

    function discardAndClose(): bool {
        if (root.busy)
            return false;
        AppearanceCoordinator.close();
        Preferences.cancel();
        root.ownerScreenName = "";
        root.requestedPage = "general";
        root.discardConfirmationVisible = false;
        return true;
    }

    function forceCancelAndClose(): bool {
        return root.discardAndClose();
    }

    function closeForOwnerLoss(): bool { return root.closeForSessionLock(); }

    function closeForSessionLock(): bool {
        AppearanceCoordinator.close();
        if (!Preferences.savePending)
            Preferences.cancel();
        root.ownerScreenName = "";
        root.requestedPage = "general";
        root.discardConfirmationVisible = false;
        return true;
    }

    function restoreDefaults(allPages: bool): bool {
        if (!root.active || root.busy || !AppearanceCoordinator.editable())
            return false;
        const page = root.requestedPage;
        const paths = allPages ? ["locale", "accessibility", "applications", "modules"]
            : SettingsCatalog.resetPaths(page).filter(path => path !== "appearance");
        if (!allPages && SettingsCatalog.resetPaths(page).length === 0)
            return false;
        if (allPages || page === "appearance" || page === "general") {
            if (!AppearanceCoordinator.restoreDefaults(allPages || page === "appearance"))
                return false;
        }
        return Preferences.restorePaths(paths);
    }

    function apply(): bool {
        if (!root.active || root.busy)
            return false;
        root.discardConfirmationVisible = false;
        return AppearanceCoordinator.apply();
    }
}
