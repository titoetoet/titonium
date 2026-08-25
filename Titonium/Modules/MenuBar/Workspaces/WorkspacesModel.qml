pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Platform.Hyprland

QtObject {
    id: root

    required property var screen
    property int count: 5

    readonly property int activeWorkspaceId: HyprlandAdapter.activeWorkspaceId(root.screen)
    readonly property var items: HyprlandAdapter.workspaceSnapshot(root.screen, root.count)

    function activate(workspaceId: int): void {
        HyprlandAdapter.activateWorkspace(workspaceId);
    }
}
