pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Titonium.AgentApproval
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.AgentApproval
import qs.Titonium.Services.Mpris
import qs.Titonium.Services.Notifications
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    required property ShellScreen screenModel
    property bool entranceRequested: Motion.reduced
    property bool closing: false
    property real islandRadius: 18
    signal expandedRequested()
    signal dragStarted()
    signal dragFinished(real offset, real velocity)
    readonly property bool isBanner: CenterNotchCoordinator.requestedPage === "banner"
    readonly property var context: CenterNotchCoordinator.selectedContext
    readonly property string contextSource: String(root.context?.source || "idle")
    readonly property bool agentContext: root.contextSource === "agent"
    readonly property bool mediaContext: root.contextSource === "media"
    readonly property bool focusContext: root.contextSource === "focus"
    readonly property bool notificationContext: root.contextSource === "notification"
    property real canvasContentProgress: root.isBanner
        ? CenterNotchCoordinator.dragProgress : 1
    readonly property var notification: {
        const id = Number(root.context?.id || 0);
        for (let index = 0; index < NotificationService.notifications.length; index++) {
            if (NotificationService.notifications[index].id === id)
                return NotificationService.notifications[index];
        }
        return null;
    }

    focus: true
    clip: true

    Behavior on canvasContentProgress {
        enabled: CenterNotchCoordinator.dragProgress <= 0
        NumberAnimation {
            duration: Motion.reduced ? 0 : 180
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: contentLayer
        anchors.fill: parent
        opacity: root.closing ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Motion.reduced ? 0 : 90; easing.type: Easing.OutQuad } }

        Item {
            id: bannerLayer
            anchors.fill: parent
            visible: opacity > 0
            enabled: root.canvasContentProgress < 0.25
            opacity: 1 - root.canvasContentProgress

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 54
                anchors.bottomMargin: 6
                spacing: 10
                visible: root.mediaContext

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 10
                    color: Theme.light ? "#eef0f4" : "#17191f"
                    clip: true

                    Image {
                        id: artwork
                        anchors.fill: parent
                        source: MprisService.selectedPlayer?.trackArtUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                    Shared.Icon {
                        anchors.centerIn: parent
                        visible: artwork.status !== Image.Ready
                        name: "album"
                        size: 24
                        tone: "accent"
                    }
                    TapHandler { onTapped: root.expandedRequested() }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: MprisService.selectedPlayer?.trackTitle
                            || root.context?.title || I18n.tr("menubar.center.media_unknown")
                        variant: "label"
                        strong: true
                        elide: Text.ElideRight
                    }
                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: MprisService.selectedPlayer?.trackArtist || ""
                        visible: text.length > 0
                        variant: "caption"
                        tone: "secondary"
                        elide: Text.ElideRight
                    }
                    TapHandler { onTapped: root.expandedRequested() }
                }

                RowLayout {
                    spacing: 4
                    Shared.Button { size: "small"; variant: "quiet"; iconName: "skip_previous"; showFocusRing: false; onTriggered: MprisService.previous() }
                    Shared.Button { size: "small"; variant: "primary"; iconName: MprisService.playing ? "pause" : "play_arrow"; showFocusRing: false; onTriggered: MprisService.togglePlaying() }
                    Shared.Button { size: "small"; variant: "quiet"; iconName: "skip_next"; showFocusRing: false; onTriggered: MprisService.next() }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2.5
                visible: root.mediaContext
                color: Qt.rgba(1, 1, 1, 0.12)
                Rectangle {
                    height: parent.height
                    color: Theme.accent
                    width: {
                        const player = MprisService.selectedPlayer;
                        if (!player || !player.trackLength)
                            return 0;
                        return parent.width * Math.min(1, Math.max(0,
                            player.trackPosition / player.trackLength));
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 54
                spacing: 10
                visible: root.notificationContext
                Shared.Icon { name: "notifications"; size: 20; tone: "accent" }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: root.notification?.summary || root.context?.title || I18n.tr("menubar.center.notification_new")
                        variant: "label"
                        strong: true
                        elide: Text.ElideRight
                    }
                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: root.notification?.body || ""
                        visible: text.length > 0
                        variant: "caption"
                        tone: "secondary"
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                anchors.centerIn: parent
                visible: root.focusContext
                spacing: 10
                Shared.Button {
                    size: "small"
                    variant: CenterNotchCoordinator.focusEnabled ? "primary" : "quiet"
                    iconName: CenterNotchCoordinator.focusEnabled
                        ? "center_focus_strong" : "center_focus_weak"
                    accessibleName: CenterNotchCoordinator.focusEnabled
                        ? "Disable Focus" : "Enable Focus"
                    onTriggered: CenterNotchCoordinator.toggleFocus()
                }
                Shared.TextLabel {
                    text: root.context?.title || I18n.tr("menubar.center.focus_fallback")
                    variant: "label"
                    strong: true
                }
            }

            RowLayout {
                anchors.centerIn: parent
                visible: !root.agentContext && !root.mediaContext
                    && !root.notificationContext && !root.focusContext
                spacing: 8
                Shared.Icon { name: root.context?.icon || "bolt"; size: 20; tone: "accent" }
                Shared.TextLabel { text: root.context?.title || I18n.tr("center_notch.live_activity"); variant: "label"; strong: true }
            }

            Shared.Button {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 10
                size: "small"
                variant: "quiet"
                iconName: "open_in_full"
                accessibleName: I18n.tr("menubar.center_notch.accessible")
                onTriggered: root.expandedRequested()
            }

            Item {
                id: dragHandle
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 12

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    width: 42
                    height: 3
                    radius: 1.5
                    color: Theme.borderStrong
                    opacity: 0.7
                }

                DragHandler {
                    id: expandDrag
                    target: null
                    xAxis.enabled: false
                    yAxis.minimum: 0
                    onTranslationChanged: CenterNotchCoordinator.setDragProgress(
                        Math.max(0, expandDrag.translation.y) / 160)
                    onActiveChanged: {
                        if (active) {
                            root.dragStarted();
                        } else {
                            root.dragFinished(
                                Math.max(0, expandDrag.translation.y),
                                Math.max(0, expandDrag.centroid.velocity.y));
                        }
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: opacity > 0
            enabled: root.canvasContentProgress > 0.75
            opacity: root.canvasContentProgress

            Item {
                id: expandedHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 48

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Shared.Icon {
                        name: root.agentContext ? "smart_toy" : "dashboard_customize"
                        size: 18
                        tone: root.agentContext ? "warning" : "accent"
                    }
                    Shared.TextLabel {
                        text: root.agentContext
                            ? I18n.tr("agent_approval.needs_approval")
                            : I18n.tr("center_notch.dynamic_island")
                        variant: "label"
                        strong: true
                    }
                }
                Shared.Button {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    size: "small"
                    variant: "quiet"
                    iconName: "keyboard_arrow_up"
                    accessibleName: I18n.tr("center_notch.collapse")
                    onTriggered: CenterNotchCoordinator.collapse()
                }
            }

            Rectangle {
                anchors.top: expandedHeader.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                anchors.topMargin: 0
                radius: 20
                color: Theme.light ? "#f8f9fb" : "#13151a"
                border.width: 1
                border.color: Theme.light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.06)

                AgentApprovalCard {
                    id: expandedAgentApproval
                    anchors.fill: parent
                    visible: root.agentContext && AgentApprovalService.hasPending
                    enabled: visible
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: !root.agentContext
                    Shared.Icon { Layout.alignment: Qt.AlignHCenter; name: "dashboard_customize"; size: 32; tone: "accent" }
                    Shared.TextLabel { Layout.alignment: Qt.AlignHCenter; text: I18n.tr("center_notch.canvas.title"); variant: "heading"; strong: true }
                    Shared.TextLabel { Layout.alignment: Qt.AlignHCenter; text: I18n.tr("center_notch.canvas.description"); variant: "body"; tone: "secondary" }
                }
            }
        }
    }
}
