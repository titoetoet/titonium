pragma Singleton

import QtQuick

QtObject {
    readonly property url unknownSource: Qt.resolvedUrl("../Modules/MenuBar/DiagnosticUnknown.qml")

    readonly property var sources: ({
        "diagnostic.label": Qt.resolvedUrl("../Modules/MenuBar/DiagnosticLabel.qml"),
        "diagnostic.screen": Qt.resolvedUrl("../Modules/MenuBar/DiagnosticScreen.qml")
    })

    function sourceFor(widgetType: string): url {
        return sources[widgetType] || unknownSource;
    }
}
