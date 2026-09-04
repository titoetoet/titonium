pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces.Center
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Bar.classic
import qs.Titonium.Bar.right
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import "BarVisibilityRules.js" as BarVisibilityRules

PanelWindow {
    id: root
    required property ShellScreen screenModel
    readonly property int barHeight: Metrics.barHeight
    readonly property int edgeRevealHeight: 2
    readonly property bool revealRequested: BarVisibilityRules.shouldReveal(
        BarVisibilityState.pinned, edgeRevealHover.hovered, root.barHovered)
        || CenterSurfaceController.active || RightPillCoordinator.active
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
    readonly property var connectedLeftHitbox:
        root.hitbox(connectedBarLoader.item, "leftHitbox")
    readonly property var connectedRightHitbox:
        root.hitbox(connectedBarLoader.item, "rightHitbox")
    readonly property var classicArchHitbox:
        root.hitbox(classicBarLoader.item, "archHitbox")
    readonly property var classicWorkspaceHitbox:
        root.hitbox(classicBarLoader.item, "workspaceHitbox")
    readonly property var classicActiveWindowHitbox:
        root.hitbox(classicBarLoader.item, "activeWindowHitbox")
    readonly property var classicPinHitbox:
        root.hitbox(classicBarLoader.item, "pinHitbox")
    readonly property var classicConnectivityHitbox:
        root.hitbox(classicBarLoader.item, "connectivityHitbox")
    readonly property var classicStatusHitbox:
        root.hitbox(classicBarLoader.item, "statusHitbox")
    readonly property bool barHovered: root.activeBar ? root.activeBar.hovered : false

    function hitbox(item: var, name: string): var {
        return item ? item[name] : null;
    }
    mask: Region {
        Region { item: edgeReveal }
        Region { item: root.connectedLeftHitbox }
        Region { item: root.connectedRightHitbox }
        Region { item: root.classicArchHitbox }
        Region { item: root.classicWorkspaceHitbox }
        Region { item: root.classicActiveWindowHitbox }
        Region { item: root.classicPinHitbox }
        Region { item: root.classicConnectivityHitbox }
        Region { item: root.classicStatusHitbox }
    }

    Component {
        id: connectedBarComponent

        Bar {
            width: parent.width
            height: parent.height
            screen: root.screenModel
        }
    }

    Component {
        id: classicBarComponent

        ClassicBar {
            width: parent.width
            height: parent.height
            screen: root.screenModel
        }
    }

    Loader {
        id: connectedBarLoader
        active: RightPillCoordinator.presentedStyle === "connected"
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
        active: RightPillCoordinator.presentedStyle === "classic"
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
