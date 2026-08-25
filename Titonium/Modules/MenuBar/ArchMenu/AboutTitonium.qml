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
    readonly property string ownerId: root.descriptor?.ownerId || ""

    anchors.fill: parent
    focus: true

    function close(): void {
        SurfaceCoordinator.close(root.ownerId);
    }

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

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
        width: 320
        height: aboutContent.implicitHeight + padding * 2
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Metrics.barHeight + Metrics.spacingSmall
        anchors.leftMargin: Metrics.barPadding
        padding: Metrics.spacingLarge

        ColumnLayout {
            id: aboutContent
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Metrics.spacingMedium

            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                source: Qt.resolvedUrl("../../../../assets/icons/archlinux.svg")
                sourceSize.width: 48
                sourceSize.height: 48
                fillMode: Image.PreserveAspectFit
            }

            Controls.TextLabel {
                Layout.alignment: Qt.AlignHCenter
                text: AppMetadata.name
                variant: "title_large"
                strong: true
            }

            Controls.TextLabel {
                Layout.alignment: Qt.AlignHCenter
                text: I18n.tr("arch_menu.about.version", { "version": AppMetadata.version })
                variant: "caption"
                tone: "secondary"
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Metrics.borderWidth
                color: Theme.border
                Accessible.role: Accessible.Separator
            }

            Controls.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("arch_menu.about.theme", { "theme": AppMetadata.themeIdentity })
                variant: "body"
                horizontalAlignment: Text.AlignHCenter
            }

            Controls.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("arch_menu.about.session", {
                    "technologies": AppMetadata.sessionTechnologies.join(" · ")
                })
                variant: "body"
                tone: "secondary"
                horizontalAlignment: Text.AlignHCenter
            }

            Controls.Button {
                Layout.fillWidth: true
                label: I18n.tr("arch_menu.about.close")
                accessibleName: label
                onTriggered: root.close()
            }
        }
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: root.forceActiveFocus(Qt.PopupFocusReason)
}
