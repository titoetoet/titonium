pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Services.WindowSwitcher
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    required property var window
    readonly property bool selected: WindowSwitcherService.selectedId === root.window?.id

    width: 152
    height: 118
    Accessible.role: Accessible.Button
    Accessible.name: root.window?.title || root.window?.appId || ""

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusMedium
        color: root.selected ? Theme.surfaceInteractive : Theme.surface
        border.width: root.selected ? Metrics.borderWidth : 0
        border.color: root.selected ? Theme.focus : "transparent"
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
            tone: root.window?.urgent ? "warning" : (root.selected ? "accent" : "primary")
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
