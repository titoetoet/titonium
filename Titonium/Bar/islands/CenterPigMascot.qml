pragma ComponentBehavior: Bound

import QtQuick
import "../../../demos/dancing_pig" as DancingPigDemo

Item {
    id: root

    property bool resting: true
    readonly property real leftEdge: -10
    readonly property real rightEdge: Math.max(root.leftEdge, root.parent.width - width + 10)
    readonly property real topEdge: -9
    readonly property real bottomEdge: 5

    width: 48
    height: 42
    x: root.leftEdge
    y: root.topEdge
    z: 4

    DancingPigDemo.DancingPig {
        width: 260
        height: 220
        scale: 0.22
        transformOrigin: Item.TopLeft
        danceStyle: "walk"
        walkDistance: 0
        bpm: 112
        paused: root.resting
        showNotes: false
        showHearts: false
        showShadow: false
    }

    SequentialAnimation {
        id: perimeterRoute
        running: root.visible

        ScriptAction {
            script: {
                root.x = root.leftEdge;
                root.y = root.topEdge;
                root.resting = true;
            }
        }
        PauseAnimation { duration: 2600 }
        ScriptAction { script: root.resting = false }
        NumberAnimation {
            target: root
            property: "x"
            to: root.rightEdge
            duration: 5200
            easing.type: Easing.InOutSine
        }
        ScriptAction { script: root.resting = true }
        PauseAnimation { duration: 1900 }
        ScriptAction { script: root.resting = false }
        NumberAnimation {
            target: root
            property: "y"
            to: root.bottomEdge
            duration: 650
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "x"
            to: root.leftEdge
            duration: 5200
            easing.type: Easing.InOutSine
        }
        ScriptAction { script: root.resting = true }
        PauseAnimation { duration: 2200 }
        ScriptAction { script: root.resting = false }
        NumberAnimation {
            target: root
            property: "y"
            to: root.topEdge
            duration: 650
            easing.type: Easing.InOutQuad
        }
        onFinished: {
            if (root.visible)
                Qt.callLater(() => perimeterRoute.restart());
        }
    }
}
