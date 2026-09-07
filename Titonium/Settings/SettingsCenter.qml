pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme

FocusScope {
    id: root
    focus: true
    opacity: Motion.reduced ? 1 : 0
    scale: Motion.reduced ? 1 : 0.98

    ParallelAnimation {
        id: settingsEntrance
        running: !Motion.reduced

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "scale"
            from: 0.98
            to: 1
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
    }

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
        if (AppearanceCoordinator.trialActive) AppearanceCoordinator.cancelTrial();
        else SettingsCoordinator.requestClose();
        event.accepted = true;
    }
}
