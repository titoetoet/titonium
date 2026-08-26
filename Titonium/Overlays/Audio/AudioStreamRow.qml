pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Audio
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var stream
    readonly property bool available: root.stream?.available === true
    readonly property real volume: root.stream?.volume || 0
    readonly property bool muted: root.stream?.muted === true

    implicitHeight: row.implicitHeight
    implicitWidth: row.implicitWidth

    function setVolume(value: real): void {
        if (root.available)
            AudioService.setStreamVolume(root.stream.id, value);
    }

    function toggleMute(): void {
        if (root.available)
            AudioService.toggleStreamMute(root.stream.id);
    }

    RowLayout {
        id: row
        width: parent.width
        spacing: Metrics.spacingMedium

        Shared.Icon {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            name: root.stream?.icon || "audio-x-generic"
            size: 22
            tone: root.available ? "secondary" : "disabled"
            accessibleName: ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingXSmall

            Shared.TextLabel {
                Layout.fillWidth: true
                text: root.stream?.name || I18n.tr("audio.stream.fallback")
                variant: "body"
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }

            AudioSlider {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.controlHeightSmall
                enabled: root.available
                serviceValue: root.volume
                maximumValue: 1
                accessibleName: I18n.tr("audio.volume.accessible", {
                    "percentage": Math.round(root.volume * 100)
                })
                onUserValueChanged: value => root.setVolume(value)
            }
        }

        Shared.Button {
            Layout.alignment: Qt.AlignVCenter
            iconName: root.muted ? "volume_off" : "volume_up"
            variant: "quiet"
            size: "small"
            enabled: root.available
            accessibleName: I18n.tr(root.muted ? "audio.unmute.accessible" : "audio.mute.accessible", {
                "name": root.stream?.name || I18n.tr("audio.stream.fallback")
            })
            onTriggered: root.toggleMute()
        }
    }
}
