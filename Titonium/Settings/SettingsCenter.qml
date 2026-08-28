pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme

FocusScope {
    id: root
    focus: true

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        radius: Metrics.radiusLarge
        border.width: Metrics.borderWidth
        border.color: Theme.borderStrong
    }

    SettingsWorkspace {
        anchors.fill: parent
        anchors.margins: Metrics.borderWidth
    }

    Keys.onEscapePressed: event => {
        SettingsCoordinator.requestClose();
        event.accepted = true;
    }
}
