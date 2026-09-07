pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "MusicPlayerRules.js" as Rules

Item {
    id: root
    required property var context
    property var actions: []
    property bool interactionEnabled: true
    property bool titleManagedExternally: false
    signal intentRequested(var intent)
    readonly property var playback: root.context?.details?.playback || ({})
    readonly property bool stacked: width < 560
    implicitWidth: 604
    implicitHeight: root.stacked ? 272 : 152

    function capability(id: string): var {
        return root.actions.find(action => action.id === id && action.contextId === root.context?.id) || null;
    }
    function invoke(id: string): void {
        const action = root.capability(id);
        if (root.interactionEnabled && action?.enabled)
            root.intentRequested({ type: "invoke-action", actionId: id, contextId: root.context.id });
    }
    Controls.ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        contentHeight: root.implicitHeight
        clip: true
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        Item {
            width: root.width
            height: root.implicitHeight
            MusicArtwork {
                id: artwork
                objectName: "musicArtwork"
                x: root.stacked ? 16 : 24; y: root.stacked ? 16 : 24
                width: root.stacked ? 64 : 100
                height: width
                artwork: root.context?.details?.trackArtUrl || ""
            }
            Item {
                id: main
                objectName: "musicMain"
                x: artwork.x + artwork.width + (root.stacked ? 16 : 24)
                y: root.stacked ? 16 : 24
                width: Math.max(0, (root.stacked ? root.width - 16 : rightColumn.x - 24) - x)
                height: root.stacked ? 120 : 112
                MusicTransitionTitle {
                    id: title
                    opacity: root.titleManagedExternally ? 0 : 1
                    width: parent.width
                    text: root.context?.title || I18n.tr("menubar.center.media_unknown")
                    progress: 1
                    playing: root.context?.details?.playing === true
                    animationEnabled: !root.titleManagedExternally && root.interactionEnabled
                }
                Shared.TextLabel {
                    anchors.top: title.bottom
                    anchors.topMargin: 4
                    width: parent.width
                    text: root.context?.subtitle || ""
                    variant: "caption"
                    tone: "secondary"
                    elide: Text.ElideRight
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 46
                    spacing: root.stacked ? 16 : Math.max(16, main.width * 0.14)
                    Shared.Button {
                        objectName: "musicPrevious"
                        width: 36; height: 40
                        variant: "quiet"; backgroundRadius: Metrics.radiusMedium
                        Shared.Icon {
                            anchors.centerIn: parent
                            name: "skip_previous"; size: 26; fill: 1
                        }
                        accessibleName: I18n.tr("center.music.previous")
                        enabled: root.interactionEnabled && !!root.capability("media.previous")?.enabled
                        onTriggered: root.invoke("media.previous")
                    }
                    Shared.Button {
                        objectName: "musicToggle"
                        width: 40; height: 40
                        backgroundRadius: 20
                        backgroundVisible: false
                        iconColor: Theme.background
                        Rectangle {
                            anchors.fill: parent
                            z: -1
                            radius: width / 2
                            color: parent.hovered ? Theme.textSecondary : Theme.textPrimary
                            border.width: parent.activeFocus ? 2 : 0
                            border.color: Theme.focus
                        }
                        variant: "quiet"
                        Shared.Icon {
                            anchors.centerIn: parent
                            name: root.context?.details?.playing ? "pause" : "play_arrow"
                            size: 26; fill: 1
                            color: Theme.background
                        }
                        accessibleName: I18n.tr(root.context?.details?.playing ? "center.music.pause" : "center.music.play")
                        enabled: root.interactionEnabled && !!root.capability("media.toggle")?.enabled
                        onTriggered: root.invoke("media.toggle")
                    }
                    Shared.Button {
                        objectName: "musicNext"
                        width: 36; height: 40
                        variant: "quiet"; backgroundRadius: Metrics.radiusMedium
                        Shared.Icon {
                            anchors.centerIn: parent
                            name: "skip_next"; size: 26; fill: 1
                        }
                        accessibleName: I18n.tr("center.music.next")
                        enabled: root.interactionEnabled && !!root.capability("media.next")?.enabled
                        onTriggered: root.invoke("media.next")
                    }
                }
                RowLayout {
                    y: root.stacked ? 90 : 86; height: 28
                    width: parent.width
                    spacing: 4
                    Shared.TextLabel {
                        text: Rules.duration(root.playback.position)
                        variant: "caption"; tone: "secondary"
                        font.features: ({ "tnum": 1 })
                    }
                    MusicSeek {
                        objectName: "musicSeek"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        playback: root.playback
                        contextId: root.context?.id || ""
                        enabled: root.interactionEnabled && root.playback.canSeek === true && root.playback.length > 0
                        onIntentRequested: intent => root.intentRequested(intent)
                    }
                    Shared.TextLabel {
                        text: root.playback.length > 0 ? Rules.duration(root.playback.length) : "—"
                        variant: "caption"; tone: "secondary"
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
            Rectangle {
                x: root.stacked ? 16 : rightColumn.x - 12
                y: root.stacked ? 148 : 16
                width: root.stacked ? root.width - 32 : 1
                height: root.stacked ? 1 : 120
                color: Theme.border
                opacity: 0.45
            }
            Item {
                id: rightColumn
                objectName: "musicUpcoming"
                x: root.stacked ? 16 : root.width - width - 24
                y: root.stacked ? 164 : 24
                width: root.stacked ? root.width - 32 : 164
                height: 104
                MusicSpectrum {
                    objectName: "musicSpectrum"
                    width: parent.width; height: 32
                    playing: root.context?.details?.playing === true
                }
                Shared.TextLabel {
                    y: 42
                    objectName: "musicSourceHeading"
                    text: I18n.tr("center.music.now_playing")
                    variant: "micro"; tone: "secondary"
                }
                RowLayout {
                    objectName: "musicSource"
                    y: 64; width: parent.width; height: 36
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 10
                        color: Theme.surfaceElevated
                        Shared.Icon {
                            anchors.centerIn: parent
                            name: root.playback.source?.icon || "music_note"
                            size: 22; fill: 1
                            tone: "primary"
                        }
                    }
                    Shared.TextLabel {
                        objectName: "musicSourceLabel"
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: {
                            const label = root.playback.source?.label || "";
                            return label.startsWith("YouTube · ") ? "YouTube"
                                : label || I18n.tr("menubar.center.media_unknown");
                        }
                        variant: "body"
                        tone: "primary"
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
