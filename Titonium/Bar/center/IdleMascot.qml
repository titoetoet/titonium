pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Theme
import qs.Titonium.Shared.Mascots.Dog

Item {
    id: root
    property bool hovered: false
    property string templateId: "pig"
    property int reaction: -1
    readonly property var reactions: ["CoffeePig.qml", "CoderPig.qml", "WalkingPig.qml"]
    readonly property bool awake: root.hovered && !Motion.reduced
    onAwakeChanged: {
        if (root.awake) {
            const offset = 1 + Math.floor(Math.random() * (root.reactions.length - 1));
            root.reaction = root.reaction < 0 ? Math.floor(Math.random() * root.reactions.length)
                : (root.reaction + offset) % root.reactions.length;
        }
    }
    readonly property bool isDog: root.templateId === "dog"
    clip: !root.isDog
    Item {
        visible: !root.isDog
        anchors.centerIn: parent
        width: 260
        height: 250
        scale: Math.min(root.height / 250, root.width / 260)
        Loader {
            id: sleeping
            anchors.fill: parent
            active: root.visible && !root.isDog
            source: "../../Shared/Mascots/Pig/SleepyPig.qml"
            enabled: false
            opacity: root.awake ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Motion.reduced ? 0 : 180 } }
        }
        Loader {
            id: reacting
            anchors.fill: parent
            active: root.visible && !root.isDog && root.awake
            source: root.reaction >= 0 ? "../../Shared/Mascots/Pig/" + root.reactions[root.reaction] : ""
            enabled: false
            opacity: root.awake ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.reduced ? 0 : 180 } }
        }
    }
    Loader {
        anchors.fill: parent
        active: root.visible && root.isDog
        sourceComponent: Component {
            PixelStageDog {
                paused: Motion.reduced
            }
        }
    }
    Binding { target: sleeping.item; property: "paused"; value: Motion.reduced || root.awake; when: sleeping.item !== null }
    Binding { target: sleeping.item; property: "pigColor"; value: root.templateId === "pig-lavender" ? "#C8B6FF" : "#FFB6C1"; when: sleeping.item !== null }
    Binding { target: reacting.item; property: "paused"; value: Motion.reduced || !root.awake; when: reacting.item !== null }
    Binding { target: reacting.item; property: "pigColor"; value: root.templateId === "pig-lavender" ? "#C8B6FF" : "#FFB6C1"; when: reacting.item !== null }
}
