pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Bar.notch
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Applications
import qs.Titonium.Services.Hyprland
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "CenterActivityRules.js" as CenterActivityRules

FocusScope {
    id: root
    required property var screen

    readonly property var activeWindow: HyprlandService.activeWindow
    readonly property string appName: root.activeWindow
        ? ApplicationService.nameForAppId(root.activeWindow.appId) : ""
    readonly property string activityLabel: CenterActivityRules.label(
        root.appName, root.activeWindow?.title || "")
    readonly property bool notchOpen: CenterNotchCoordinator.ownerScreenName === root.screen.name

    implicitWidth: Math.min(520, Math.max(180,
        activityRow.implicitWidth + Metrics.spacingLarge * 2))
    implicitHeight: Metrics.controlHeight
    activeFocusOnTab: true

    function activate(): void {
        CenterNotchCoordinator.toggle(root.screen.name);
    }

    Shared.Surface {
        anchors.fill: parent
        tone: centerHover.hovered || root.notchOpen ? "interactive" : "elevated"
        radius: Metrics.radiusLarge
    }

    RowLayout {
        id: activityRow
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingLarge
        anchors.rightMargin: Metrics.spacingLarge
        spacing: Metrics.spacingSmall

        Shared.SystemIcon {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            sourceName: root.activeWindow?.icon || ""
            fallbackName: "deployed_code"
            size: 20
            tone: root.notchOpen ? "accent" : "secondary"
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            text: root.activityLabel
            variant: "label"
            strong: root.notchOpen
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    HoverHandler {
        id: centerHover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.activate();
        }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter) {
            root.activate();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr("menubar.center_notch.accessible")
    Accessible.focusable: true
}
