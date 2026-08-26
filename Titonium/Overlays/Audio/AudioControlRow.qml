pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Audio
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    property string kind: "output"
    readonly property bool isOutput: root.kind === "output"
    readonly property bool isInput: root.kind === "input"
    readonly property bool available: root.isOutput ? AudioService.outputAvailable
        : (root.isInput ? AudioService.inputAvailable : false)
    readonly property string label: root.isOutput ? AudioService.outputName
        : (root.isInput ? AudioService.inputName : "")
    readonly property string icon: root.isOutput ? AudioService.outputIcon : "mic"
    readonly property real volume: root.isOutput ? AudioService.outputVolume
        : (root.isInput ? AudioService.inputVolume : 0)
    readonly property bool muted: root.isOutput ? AudioService.outputMuted
        : (root.isInput ? AudioService.inputMuted : false)
    readonly property real maximumValue: root.isOutput ? AudioService.maximumOutputVolume : 1

    implicitHeight: row.implicitHeight
    implicitWidth: row.implicitWidth

    function setVolume(value: real): void {
        if (!root.available)
            return;
        if (root.isOutput)
            AudioService.setOutputVolume(value);
        else if (root.isInput)
            AudioService.setInputVolume(value);
    }

    function toggleMute(): void {
        if (!root.available)
            return;
        if (root.isOutput)
            AudioService.toggleOutputMute();
        else if (root.isInput)
            AudioService.toggleInputMute();
    }

    RowLayout {
        id: row
        width: parent.width
        spacing: Metrics.spacingMedium

        Shared.Icon {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            name: root.icon
            size: 22
            tone: root.available ? "secondary" : "disabled"
            accessibleName: ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingXSmall

            Shared.TextLabel {
                Layout.fillWidth: true
                text: root.label
                variant: "label"
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }

            AudioSlider {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.controlHeightSmall
                enabled: root.available
                serviceValue: root.volume
                maximumValue: root.maximumValue
                accessibleName: I18n.tr("audio.volume.accessible", {
                    "percentage": Math.round(root.volume * 100)
                })
                onUserValueChanged: value => root.setVolume(value)
            }
        }

        Shared.Button {
            Layout.alignment: Qt.AlignVCenter
            iconName: root.muted ? "volume_off" : root.icon
            variant: "quiet"
            size: "small"
            enabled: root.available
            accessibleName: I18n.tr(root.muted ? "audio.unmute.accessible" : "audio.mute.accessible", {
                "name": root.label
            })
            onTriggered: root.toggleMute()
        }
    }
}
