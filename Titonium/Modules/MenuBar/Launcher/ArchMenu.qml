pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    property string selectedSection: root.descriptor?.section || "apps"
    readonly property string ownerId: root.descriptor?.ownerId || ""

    anchors.fill: parent
    focus: true

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    function close(): void { SurfaceCoordinator.close(root.ownerId); }

    function selectSection(sectionId: string): void {
        const known = LauncherSectionRegistry.sections.some(section => section.id === sectionId);
        root.selectedSection = known ? sectionId : "apps";
        if (!known)
            LauncherSectionRegistry.sourceFor(sectionId);
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.28)
        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(panel, eventPoint.position))
                    root.close();
            }
        }
    }

    Controls.Panel {
        id: panel
        z: 1
        width: Math.min(980, root.width - Metrics.spacingLarge * 2)
        height: Math.min(700, root.height - Metrics.barHeight - Metrics.spacingLarge * 2)
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Metrics.barHeight + Metrics.spacingSmall
        anchors.leftMargin: Metrics.barPadding
        padding: 0

        RowLayout {
            anchors.fill: parent
            spacing: 0

            LauncherRail {
                Layout.preferredWidth: 68
                Layout.fillHeight: true
                sections: LauncherSectionRegistry.sections
                selectedSection: root.selectedSection
                onSectionSelected: sectionId => root.selectSection(sectionId)
            }

            Rectangle { Layout.fillHeight: true; implicitWidth: Metrics.borderWidth; color: Theme.border }

            Loader {
                id: sectionLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: LauncherSectionRegistry.sourceFor(root.selectedSection)
            }

            Connections {
                target: sectionLoader.item || null
                ignoreUnknownSignals: true
                function onApplicationLaunched(): void { root.close(); }
            }
        }
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: root.forceActiveFocus(Qt.PopupFocusReason)
}
