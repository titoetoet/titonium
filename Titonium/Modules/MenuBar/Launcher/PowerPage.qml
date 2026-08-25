pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation
import qs.Titonium.Platform.System

FocusScope {
    id: root
    property string pendingAction: ""
    readonly property var actions: [
        { "id": "sleep", "icon": "bedtime" },
        { "id": "hibernate", "icon": "ac_unit" },
        { "id": "logout", "icon": "logout" },
        { "id": "restart", "icon": "restart_alt" },
        { "id": "shutdown", "icon": "power_settings_new" }
    ].filter(action => SessionActions.supportedActions.indexOf(action.id) >= 0)

    function confirm(): void {
        const action = root.pendingAction;
        if (action.length > 0 && SessionActions.executeConfirmed(action))
            root.pendingAction = "";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingLarge
        spacing: Metrics.spacingLarge

        Controls.TextLabel { text: I18n.tr("launcher.section.power"); variant: "title_large"; strong: true }
        Rectangle { Layout.fillWidth: true; implicitHeight: Metrics.borderWidth; color: Theme.border; opacity: 0.55 }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rowSpacing: Metrics.spacingMedium
            columnSpacing: Metrics.spacingMedium

            Repeater {
                model: root.actions
                Controls.Button {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 112
                    label: I18n.tr("launcher.action." + modelData.id)
                    iconName: modelData.icon
                    variant: modelData.id === "shutdown" || modelData.id === "restart" ? "danger" : "secondary"
                    enabled: !SessionActions.busy
                    accessibleName: label
                    onTriggered: root.pendingAction = modelData.id
                }
            }
        }

        Controls.Surface {
            visible: root.pendingAction.length > 0
            Layout.fillWidth: true
            implicitWidth: 1
            implicitHeight: visible ? 72 : 0
            tone: "elevated"
            outlined: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: Metrics.spacingMedium
                Controls.TextLabel {
                    Layout.fillWidth: true
                    text: I18n.tr("launcher.action.confirm", { "action": I18n.tr("launcher.action." + root.pendingAction) })
                    strong: true
                }
                Controls.Button { label: I18n.tr("launcher.action.cancel"); onTriggered: root.pendingAction = "" }
                Controls.Button { label: I18n.tr("launcher.action.confirm_button"); variant: "danger"; onTriggered: root.confirm() }
            }
        }

        Controls.TextLabel {
            visible: SessionActions.lastError.length > 0
            Layout.fillWidth: true
            text: SessionActions.lastError
            tone: "danger"
            variant: "caption"
        }
    }
}
