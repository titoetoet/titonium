pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import "CenterNotchState.js" as CenterNotchState

FocusScope {
    id: root
    property string currentPage: "overview"
    signal pageRequested(string pageId)
    signal settingsRequested()

    readonly property var pages: [
        { "id": "overview", "icon": "dashboard" },
        { "id": "tools", "icon": "construction" },
        { "id": "session", "icon": "power_settings_new" }
    ]
    readonly property int currentIndex: Math.max(0,
        root.pages.findIndex(page => page.id === root.currentPage))

    width: 48
    implicitWidth: 48
    implicitHeight: 320
    focus: true

    Rectangle {
        id: selectionHighlight
        x: 0
        y: primaryPages.y + root.currentIndex * (48 + Metrics.spacingSmall)
        width: 48
        height: 48
        radius: Metrics.radiusMedium
        color: Theme.surfaceInteractive
        border.width: Metrics.borderWidth
        border.color: Theme.borderStrong

        Behavior on y {
            NumberAnimation { duration: Motion.normal; easing.type: Easing.OutCubic }
        }
    }

    Column {
        id: primaryPages
        anchors.top: parent.top
        anchors.left: parent.left
        spacing: Metrics.spacingSmall

        Repeater {
            model: root.pages

            Shared.Button {
                required property var modelData
                width: 48
                height: 48
                iconName: modelData.icon
                variant: "quiet"
                selected: root.currentPage === modelData.id
                accessibleName: I18n.tr("center_notch.tab." + modelData.id)
                onTriggered: root.pageRequested(modelData.id)
            }
        }
    }

    Shared.Button {
        id: settingsButton
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 48
        height: 48
        iconName: "settings"
        variant: "quiet"
        accessibleName: I18n.tr("center_notch.tab.settings")
        onTriggered: root.settingsRequested()
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.angleDelta.y > 0 ? -1 : 1;
            root.pageRequested(CenterNotchState.wheelPage(root.currentPage, delta));
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Up) {
            root.pageRequested(CenterNotchState.arrowPage(root.currentPage, -1));
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            root.pageRequested(CenterNotchState.arrowPage(root.currentPage, 1));
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            root.pageRequested("overview");
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.pageRequested("session");
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            CenterNotchCoordinator.close();
            event.accepted = true;
        }
    }
}
