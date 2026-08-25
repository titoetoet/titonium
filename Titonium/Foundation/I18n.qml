pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var vietnamese: ({})
    property var english: ({})
    readonly property string locale: ConfigStore.previewState.locale || "vi"

    function loadCatalog(fileView: FileView, localeName: string): var {
        try {
            const document = JSON.parse(fileView.text());
            return document.strings || {};
        } catch (error) {
            Logger.warn("i18n", "failed to load " + localeName + ": " + error);
            return {};
        }
    }

    function reload(): void {
        root.vietnamese = loadCatalog(viFile, "vi");
        root.english = loadCatalog(enFile, "en");
    }

    function tr(key: string, params: var): string {
        const primary = root.locale === "en" ? root.english : root.vietnamese;
        let result = primary[key] || root.english[key] || key;
        if (params && typeof params === "object") {
            Object.keys(params).forEach(name => {
                result = result.replace(new RegExp("\\{" + name + "\\}", "g"), String(params[name]));
            });
        }
        return result;
    }

    Component.onCompleted: root.reload()

    property FileView viFile: FileView {
        path: Quickshell.shellPath("config/i18n/vi.json")
        preload: false
        blockLoading: true
    }

    property FileView enFile: FileView {
        path: Quickshell.shellPath("config/i18n/en.json")
        preload: false
        blockLoading: true
    }
}
