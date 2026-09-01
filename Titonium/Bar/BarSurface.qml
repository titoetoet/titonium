pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import "BarVisibilityRules.js" as BarVisibilityRules

PanelWindow {
    id: root
    required property ShellScreen screenModel
    signal centerRequested(var screen)
    signal sourceRequested(var screen, string intent)
    readonly property int barHeight: Metrics.barHeight
    readonly property int edgeRevealHeight: 2
    readonly property bool revealRequested: BarVisibilityRules.shouldReveal(
        BarVisibilityState.pinned, edgeRevealHover.hovered, bar.hovered)
    property bool barRevealed: BarVisibilityState.pinned
    screen: root.screenModel
    color: "transparent"
    implicitHeight: root.barHeight
    exclusiveZone: BarVisibilityRules.exclusiveZone(
        BarVisibilityState.pinned, root.barHeight)
    aboveWindows: true
    WlrLayershell.namespace: "titonium-menubar"
    WlrLayershell.layer: WlrLayer.Top
    anchors { top: true; left: true; right: true }
    mask: Region {
        Region { item: bar.startHitbox }
        Region { item: bar.centerHitbox }
        Region { item: bar.pinHitbox }
        Region { item: bar.endHitbox }
        Region { item: edgeReveal }
    }

    Bar {
        id: bar
        width: parent.width
        height: root.barHeight
        y: root.barRevealed ? 0 : -root.barHeight + root.edgeRevealHeight
        screen: root.screenModel
        onCenterRequested: screen => root.centerRequested(screen)
        onSourceRequested: (screen, intent) => root.sourceRequested(screen, intent)

        Behavior on y {
            NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
        }
    }

    Item {
        id: edgeReveal
        x: 0
        y: 0
        width: parent.width
        height: root.edgeRevealHeight

        HoverHandler { id: edgeRevealHover }
    }

    Timer {
        id: hideDelay
        interval: 250
        repeat: false
        onTriggered: {
            if (!root.revealRequested)
                root.barRevealed = false;
        }
    }

    onRevealRequestedChanged: {
        if (root.revealRequested) {
            hideDelay.stop();
            root.barRevealed = true;
        } else {
            hideDelay.restart();
        }
    }
}
