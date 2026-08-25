pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Foundation
import qs.Titonium.Modules.Settings

FocusScope {
    SettingsWorkspace {
        anchors.fill: parent
        showCloseButton: false
        onApplyRequested: ConfigStore.apply()
        onCancelRequested: ConfigStore.cancel()
    }
    Component.onCompleted: if (!ConfigStore.previewActive) ConfigStore.beginPreview()
}
