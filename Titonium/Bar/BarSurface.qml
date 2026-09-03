pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Bar.classic
import qs.Titonium.Bar.notch
import qs.Titonium.Bar.right
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
        BarVisibilityState.pinned, edgeRevealHover.hovered, root.barHovered)
        || CenterNotchCoordinator.active || RightPillCoordinator.active
        || RightPillCoordinator.hovered
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
    readonly property var activeBar: connectedBarLoader.active
        ? connectedBarLoader.item : classicBarLoader.item
    readonly property var leftHitbox: root.activeBar ? root.activeBar.leftHitbox : null
    readonly property var centerHitbox: root.activeBar && classicBarLoader.active
        ? root.activeBar.centerHitbox : null
    readonly property var notificationHitbox: root.activeBar && classicBarLoader.active
        ? root.activeBar.notificationHitbox : null
    readonly property var rightHitbox: root.activeBar ? root.activeBar.rightHitbox : null
    readonly property bool barHovered: root.activeBar ? root.activeBar.hovered : false
    mask: Region {
        Region { item: edgeReveal }
        Region { item: root.leftHitbox }
        Region { item: root.centerHitbox }
        Region { item: root.notificationHitbox }
        Region { item: root.rightHitbox }
    }

    Component {
        id: connectedBarComponent

        Bar {
            width: parent.width
            height: parent.height
            screen: root.screenModel
            onCenterRequested: screen => root.centerRequested(screen)
            onSourceRequested: (screen, intent) => root.sourceRequested(screen, intent)
        }
    }

    Component {
        id: classicBarComponent

        ClassicBar {
            width: parent.width
            height: parent.height
            screen: root.screenModel
            onCenterRequested: screen => root.centerRequested(screen)
            onSourceRequested: (screen, intent) => root.sourceRequested(screen, intent)
        }
    }

    Loader {
        id: connectedBarLoader
        active: Preferences.barStyle === "connected"
        width: parent.width
        height: root.barHeight
        y: root.barRevealed ? 0 : -root.barHeight + root.edgeRevealHeight
        sourceComponent: connectedBarComponent

        Behavior on y {
            NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
        }
    }

    Loader {
        id: classicBarLoader
        active: Preferences.barStyle === "classic"
        width: parent.width
        height: root.barHeight
        y: root.barRevealed ? 0 : -root.barHeight + root.edgeRevealHeight
        sourceComponent: classicBarComponent

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

    onBarRevealedChanged: BarVisibilityState.setRevealed(root.barRevealed)
    Component.onCompleted: BarVisibilityState.setRevealed(root.barRevealed)
}
