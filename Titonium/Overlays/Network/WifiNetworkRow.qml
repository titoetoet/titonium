pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Network
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    property var network: null
    property string password: ""
    property bool passwordPromptOpen: false
    readonly property bool actionable: root.network !== null && root.network.transitioning !== true
    readonly property bool requiresPassword: root.network?.secure === true
        && root.network?.known !== true && root.network?.connected !== true

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    onNetworkChanged: root.clearPassword()

    function clearPassword(): void {
        root.password = "";
        root.passwordPromptOpen = false;
    }

    function triggerConnect(): void {
        if (!root.actionable || root.network === null)
            return;
        if (root.requiresPassword) {
            root.passwordPromptOpen = true;
        } else {
            NetworkService.connect(root.network.id);
        }
    }

    function submitPassword(): void {
        if (!root.network || root.password.length === 0)
            return;
        NetworkService.connectWithPassword(root.network.id, root.password);
        root.clearPassword();
    }

    ColumnLayout {
        id: content
        width: parent.width
        spacing: Metrics.spacingSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingMedium

            Shared.Icon {
                name: root.network?.signalIcon || "signal_wifi_0_bar"
                size: 22
                tone: root.actionable ? "secondary" : "disabled"
                accessibleName: ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingXSmall

                RowLayout {
                    Layout.fillWidth: true

                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: root.network?.name || ""
                        variant: "label"
                        strong: true
                        elide: Text.ElideRight
                    }

                    Shared.Icon {
                        visible: root.network?.secure === true
                        name: "lock"
                        size: 14
                        tone: "secondary"
                        accessibleName: ""
                    }
                }

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: I18n.tr(root.network?.stateKey || "wifi.network.available")
                        + " · " + I18n.tr(root.network?.signalKey || "wifi.signal.none")
                    tone: root.actionable ? "secondary" : "disabled"
                    variant: "caption"
                    elide: Text.ElideRight
                }
            }

            Shared.Toggle {
                visible: root.network?.connected === true
                checked: root.network?.connected === true
                enabled: root.actionable
                accessibleName: I18n.tr("wifi.network.action.accessible", {
                    "action": I18n.tr("wifi.network.disconnect"),
                    "name": root.network?.name || ""
                })
                onToggled: checked => {
                    if (!checked && root.network?.connected === true) {
                        NetworkService.disconnect(root.network.id);
                        root.clearPassword();
                    }
                }
            }

            Shared.Button {
                visible: root.network?.connected !== true
                label: I18n.tr("wifi.network.connect")
                variant: "quiet"
                size: "small"
                enabled: root.actionable
                accessibleName: I18n.tr("wifi.network.action.accessible", {
                    "action": I18n.tr("wifi.network.connect"),
                    "name": root.network?.name || ""
                })
                onTriggered: root.triggerConnect()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 22 + Metrics.spacingMedium
            visible: root.passwordPromptOpen
            spacing: Metrics.spacingSmall

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.controlHeightSmall
                radius: Metrics.radiusSmall
                color: Theme.surfaceElevated
                border.width: Metrics.borderWidth
                border.color: passwordInput.activeFocus ? Theme.focus : Theme.border

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.margins: Metrics.spacingSmall
                    color: Theme.textPrimary
                    text: root.password
                    echoMode: TextInput.Password
                    selectByMouse: true
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    Accessible.name: I18n.tr("wifi.password.accessible", {
                        "name": root.network?.name || ""
                    })
                    onTextChanged: {
                        if (text !== root.password)
                            root.password = text;
                    }
                    onAccepted: root.submitPassword()
                }
            }

            Shared.Button {
                label: I18n.tr("wifi.password.connect")
                variant: "primary"
                size: "small"
                enabled: root.password.length > 0
                onTriggered: root.submitPassword()
            }

            Shared.Button {
                iconName: "close"
                variant: "quiet"
                size: "small"
                accessibleName: I18n.tr("wifi.password.cancel")
                onTriggered: root.clearPassword()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 22 + Metrics.spacingMedium
            visible: root.network?.known === true && root.network?.connected !== true

            Shared.Button {
                label: I18n.tr("wifi.network.forget")
                iconName: "delete"
                variant: "danger"
                size: "small"
                accessibleName: I18n.tr("wifi.network.forget.accessible", {
                    "name": root.network?.name || ""
                })
                onTriggered: {
                    NetworkService.forget(root.network.id);
                    root.clearPassword();
                }
            }
        }
    }

    Component.onDestruction: root.clearPassword()
}
