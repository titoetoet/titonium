pragma Singleton

import QtQuick

QtObject {
    readonly property url unknownSource: Qt.resolvedUrl("../Modules/MenuBar/DiagnosticUnknown.qml")

    readonly property var sources: ({
        "diagnostic.label": Qt.resolvedUrl("../Modules/MenuBar/DiagnosticLabel.qml"),
        "diagnostic.screen": Qt.resolvedUrl("../Modules/MenuBar/DiagnosticScreen.qml"),
        "menubar.workspaces": Qt.resolvedUrl("../Modules/MenuBar/Workspaces/WorkspacesWidget.qml"),
        "menubar.active-window": Qt.resolvedUrl("../Modules/MenuBar/ActiveWindow/ActiveWindowWidget.qml"),
        "menubar.input-method": Qt.resolvedUrl("../Modules/MenuBar/InputMethod/InputMethodWidget.qml"),
        "menubar.clock": Qt.resolvedUrl("../Modules/MenuBar/Clock/ClockWidget.qml")
    })

    function sourceFor(widgetType: string): url {
        return sources[widgetType] || unknownSource;
    }
}
