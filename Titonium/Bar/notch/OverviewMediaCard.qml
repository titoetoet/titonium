pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Mpris
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Shared.Surface {
    id: root
    readonly property var player: MprisService.selectedPlayer
    readonly property bool hasPlayer: root.player !== null
        && (root.player.trackTitle || "").length > 0
    readonly property bool isPlaying: root.hasPlayer && root.player.playbackState === "playing"
    readonly property real trackLength: root.hasPlayer ? Number(root.player.trackLength || 0) : 0
    readonly property real trackPosition: root.hasPlayer ? Number(root.player.trackPosition || 0) : 0
    readonly property real progress: root.trackLength > 0
        ? Math.max(0, Math.min(1, root.trackPosition / root.trackLength)) : 0
    function formatTime(seconds: real): string {
        const value = Math.max(0, Math.floor(Number(seconds) || 0));
        return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0");
    }
    tone: "elevated"
    radius: Metrics.radiusMedium
    padding: Metrics.spacingMedium
    Accessible.name: I18n.tr("center_notch.overview.media.title")

    RowLayout {
        anchors.fill: parent
        spacing: Metrics.spacingMedium

        Rectangle {
            Layout.preferredWidth: 92
            Layout.preferredHeight: 92
            Layout.alignment: Qt.AlignVCenter
            radius: Metrics.radiusMedium
            color: Theme.surfaceInteractive
            clip: true

            Image {
                id: artwork
                anchors.fill: parent
                source: root.hasPlayer ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
            Rectangle {
                anchors.fill: parent
                visible: artwork.status !== Image.Ready
                color: Theme.surfaceInteractive
            }
            Shared.Icon {
                anchors.centerIn: parent
                visible: artwork.status !== Image.Ready
                name: "album"
                size: 34
                tone: root.hasPlayer ? "accent" : "secondary"
                accessibleName: root.hasPlayer ? root.player.trackTitle : ""
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingXSmall
                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: I18n.tr("center_notch.overview.media.title").toUpperCase()
                    variant: "label"
                    strong: true
                    font.letterSpacing: 0.4
                }
                Shared.TextLabel {
                    visible: root.hasPlayer
                    text: root.isPlaying
                        ? I18n.tr("center_notch.overview.media.playing")
                        : I18n.tr("center_notch.overview.media.paused")
                    variant: "caption"
                    tone: root.isPlaying ? "accent" : "secondary"
                }
                Shared.Button {
                    visible: root.hasPlayer && MprisService.playerFacts.length > 1
                    iconName: "swap_horiz"
                    size: "small"
                    variant: "quiet"
                    accessibleName: I18n.tr("center_notch.overview.media.switch_player")
                    onTriggered: MprisService.selectNextPlayer()
                }
                Shared.Button {
                    visible: root.hasPlayer
                    iconName: "open_in_new"
                    size: "small"
                    variant: "quiet"
                    accessibleName: I18n.tr("center_notch.overview.media.open")
                    onTriggered: MprisService.raiseSource()
                }
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                text: root.hasPlayer
                    ? (root.player.trackTitle || I18n.tr("menubar.center.media_unknown"))
                    : I18n.tr("center_notch.overview.media.empty")
                variant: "titleSmall"
                strong: true
                elide: Text.ElideRight
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                visible: root.hasPlayer && (root.player.trackArtist || "").length > 0
                text: visible ? root.player.trackArtist : ""
                variant: "caption"
                tone: "secondary"
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacingSmall
                Layout.preferredHeight: 4
                visible: root.hasPlayer && root.trackLength > 0
                radius: 2
                color: Theme.border
                Rectangle {
                    width: parent.width * root.progress
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.hasPlayer && root.trackLength > 0
                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: root.formatTime(root.trackPosition)
                    variant: "caption"
                    tone: "secondary"
                }
                Shared.TextLabel {
                    text: root.formatTime(root.trackLength)
                    variant: "caption"
                    tone: "secondary"
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: root.hasPlayer
                spacing: Metrics.spacingSmall
                Shared.Button {
                    iconName: "skip_previous"
                    size: "small"
                    variant: "quiet"
                    enabled: root.hasPlayer && root.player.canGoPrevious
                    accessibleName: I18n.tr("center_notch.overview.media.previous")
                    onTriggered: MprisService.previous()
                }
                Shared.Button {
                    iconName: root.isPlaying ? "pause" : "play_arrow"
                    size: "small"
                    variant: "primary"
                    enabled: root.hasPlayer && root.player.canTogglePlaying
                    accessibleName: I18n.tr("center_notch.overview.media.toggle")
                    onTriggered: MprisService.togglePlaying()
                }
                Shared.Button {
                    iconName: "skip_next"
                    size: "small"
                    variant: "quiet"
                    enabled: root.hasPlayer && root.player.canGoNext
                    accessibleName: I18n.tr("center_notch.overview.media.next")
                    onTriggered: MprisService.next()
                }
            }
        }
    }
}
