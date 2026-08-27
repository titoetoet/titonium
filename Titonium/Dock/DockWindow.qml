pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Core.Surfaces
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
    readonly property string inputRegionOwnerId: "dock:" + root.screenModel.name
    readonly property bool bodyInputVisible: root.dockRevealed || dockSurface.itemMenuActive
    readonly property rect bodyInputRect: root.bodyInputVisible
        ? root.bottomLocalToOverlayRect(Qt.rect(dockSurface.x, dockSurface.y,
            dockSurface.width, dockSurface.height)) : Qt.rect(0, 0, 0, 0)
    readonly property rect pinInputRect: root.bodyInputVisible
        ? root.bottomLocalToOverlayRect(Qt.rect(
            dockSurface.x + dockSurface.pinHitbox.x,
            dockSurface.y + dockSurface.pinHitbox.y,
            dockSurface.pinHitbox.width,
            dockSurface.pinHitbox.height)) : Qt.rect(0, 0, 0, 0)
    readonly property rect edgeInputRect: root.bottomLocalToOverlayRect(Qt.rect(edgeReveal.x,
        edgeReveal.y, edgeReveal.width, edgeReveal.height))
    signal applicationsRequested(var screen)

    function bottomLocalToOverlayRect(localRect: rect): rect {
        return Qt.rect(localRect.x, root.screenModel.height - root.reservedHeight + localRect.y,
            localRect.width, localRect.height);
    }

    function publishInputRegions(): void {
        SurfaceInputRegions.publish(root.inputRegionOwnerId, root.screenModel,
            root.bodyInputRect, root.edgeInputRect);
    }

    screen: root.screenModel
    color: "transparent"
    implicitWidth: root.screenModel.width
    implicitHeight: root.reservedHeight
    exclusiveZone: root.pinnedOpen ? root.reservedHeight : 0
    aboveWindows: true
    WlrLayershell.namespace: "titonium-dock"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: root.pinnedOpen ? ExclusionMode.Normal : ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { bottom: true; left: true; right: true }
    mask: Region {
        Region { item: dockSurface }
        Region { item: dockSurface.pinHitbox }
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

    onBodyInputRectChanged: root.publishInputRegions()
    onEdgeInputRectChanged: root.publishInputRegions()
    Component.onCompleted: root.publishInputRegions()
    Component.onDestruction: SurfaceInputRegions.clear(root.inputRegionOwnerId)
}
