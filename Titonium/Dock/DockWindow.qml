pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Services.Dock
import "../Services/Dock/DockRules.js" as DockRules

PanelWindow {
    id: root

    required property ShellScreen screenModel
    readonly property int bodyHeight: 56
    readonly property int bodyMargin: 8
    readonly property int edgeRevealHeight: 4
    readonly property int reservedHeight: 64
    readonly property bool dockRevealed: DockRules.shouldReveal(
        DockStore.autoHide,
        DockStore.pinnedOpen,
        DockService.activeWorkspaceWindowCount,
        edgeReveal.hovered,
        dockSurface.hovered || dockSurface.itemMenuActive)
    readonly property bool pinnedOpen: DockStore.pinnedOpen
    signal applicationsRequested(var screen)

    screen: root.screenModel
    color: "transparent"
    implicitWidth: root.screenModel.width
    implicitHeight: root.reservedHeight
    exclusiveZone: root.pinnedOpen ? root.reservedHeight : 0
    aboveWindows: true
    WlrLayershell.namespace: "titonium-dock"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: root.pinnedOpen ? ExclusionMode.Normal : ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors { bottom: true; left: true; right: true }
    mask: Region {
        Region { item: dockSurface }
        Region { item: edgeReveal }
    }

    DockSurface {
        id: dockSurface
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.dockRevealed ? 0 : root.reservedHeight - root.edgeRevealHeight
        revealed: root.dockRevealed
        screenModel: root.screenModel
        onApplicationsRequested: screen => root.applicationsRequested(screen)
    }

    Item {
        id: edgeReveal
        width: dockSurface.width
        height: root.edgeRevealHeight
        x: dockSurface.x
        y: root.reservedHeight - height

        HoverHandler {
            id: edgeRevealHover
        }

        readonly property bool hovered: edgeRevealHover.hovered
    }
}
