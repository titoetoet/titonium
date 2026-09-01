pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Bar.notch
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Applications
import qs.Titonium.Services.Hyprland
import qs.Titonium.Overlays.SystemTray
import qs.Titonium.Services.SystemTray
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "ActiveWindowRules.js" as ActiveWindowRules

FocusScope {
    id: root
    required property var screen

    readonly property var activeWindow: HyprlandService.activeWindow
    readonly property string appName: root.activeWindow
        ? ApplicationService.nameForAppId(root.activeWindow.appId) : ""
    readonly property bool trayMenuAvailable: SystemTrayService.hasMenuForApp(
        root.activeWindow?.appId || "", root.appName)
    readonly property string trayContext: SystemTrayService.menuContextForApp(
        root.activeWindow?.appId || "", root.appName)
    readonly property string activityLabel: ActiveWindowRules.label(
        root.appName, root.presentation.title)
    readonly property var presentation: ActiveWindowRules.presentation(
        root.appName,
        root.trayContext,
        root.activeWindow?.title || "",
        root.trayMenuAvailable)
    readonly property bool notchOpen: CenterNotchCoordinator.ownerScreenName === root.screen.name

    implicitWidth: Math.min(520, activityRow.implicitWidth + Metrics.spacingLarge * 2)
    implicitHeight: Metrics.controlHeight
    activeFocusOnTab: true
    Component.onCompleted: root.syncTraySelection()
    onActiveWindowChanged: root.syncTraySelection()
    onAppNameChanged: root.syncTraySelection()



    function syncTraySelection(): void {
        SystemTrayService.selectApp(
            root.activeWindow?.appId || "", root.appName);
    }

    function activate(): void {
        if (SystemTrayPopupCoordinator.toggleApp(
                root.screen, root, root.activeWindow?.appId || "", root.appName)) {
            CenterNotchCoordinator.close();
            return;
        }
        CenterNotchCoordinator.toggle(root.screen.name);
    }

    Shared.Surface {
        anchors.fill: parent
        tone: centerHover.hovered || root.notchOpen ? "interactive" : "elevated"
        radius: Metrics.radiusLarge
        outlined: false
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
            id: appNameLabel
            Layout.maximumWidth: 120
            text: root.presentation.appName
            variant: "label"
            strong: true
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Shared.TextLabel {
            id: activityDot
            text: "·"
            visible: root.presentation.hasContext
            variant: "label"
            tone: "secondary"
        }

        Shared.TextLabel {
            id: titleLabel
            Layout.maximumWidth: 320
            visible: root.presentation.hasContext
            text: root.presentation.title
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
