pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Services.WindowSwitcher
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "../../Theme/WorkspaceColors.js" as WorkspaceColors

FocusScope {
    id: root

    required property var window
    readonly property bool selected: WindowSwitcherService.selectedId === root.window?.id
    readonly property bool hovered: hoverHandler.hovered
    readonly property color tileColor: WorkspaceColors.tileColor(
        root.window?.workspaceId || 0, root.selected, root.hovered,
        Theme.workspacePalette, Theme.surface)

    width: 152
    height: 118
    scale: root.selected && !Motion.reduced ? 1.04 : 1.0
    Accessible.role: Accessible.Button
    Accessible.name: root.window?.title || root.window?.appId || ""

    Behavior on scale {
        NumberAnimation {
            duration: Motion.fast
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: Theme.legacy
        radius: Metrics.radiusMedium
        color: root.hovered ? Qt.lighter(root.tileColor, 1.12) : root.tileColor
        border.width: 0
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }


    Shared.StylePaint {
        anchors.fill: parent
        visible: !Theme.legacy
        tokens: Theme.tokens
        role: "button"
        radius: Metrics.radiusMedium
        customColor: root.tileColor
        outlined: false
        interaction: ({ hovered: root.hovered, selected: root.selected })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingMedium
        spacing: Metrics.spacingSmall

        Shared.SystemIcon {
            Layout.alignment: Qt.AlignHCenter
            sourceName: root.window?.icon || ""
            fallbackName: "web_asset"
            size: 56
            tone: root.window?.urgent ? "warning" : "primary"
            accessibleName: ""
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            text: root.window?.title || root.window?.appId || ""
            variant: "bodySmall"
            strong: root.selected
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered)
                WindowSwitcherService.select(root.window.id);
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            WindowSwitcherService.select(root.window.id);
            WindowSwitcherService.accept();
        }
    }
}
