pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Bar.notch
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center
import qs.Titonium.Services.Capture
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "CenterPresentationRules.js" as CenterPresentationRules

FocusScope {
    id: root

    required property var screen
    signal notchRequested(var screen)
    signal sourceRequested(var screen, string intent)
    signal settingsRequested(var screen)

    readonly property var eventPresentation:
        CenterAttentionService.presentation?.source === "media"
            || CenterAttentionService.presentation?.source === "notification"
            ? null : CenterAttentionService.presentation
    readonly property var activityPresentation: CenterNotchCoordinator.activitySlots.primary
    readonly property var primaryPresentation: root.eventPresentation || root.activityPresentation
    readonly property bool recording: ScreenRecordService.recording
    readonly property bool notchOpen: CenterNotchCoordinator.ownerScreenName === root.screen.name
    readonly property string recordingText: root.recording
        ? "REC • " + root.formatElapsed(ScreenRecordService.elapsedSeconds) : ""
    readonly property string leadingIcon: root.recording ? "screen_record"
        : (!CenterNotchCoordinator.focusEnabled && !root.eventPresentation
                && !root.activityPresentation ? "center_focus_weak"
            : CenterPresentationRules.leadingIcon(
                root.eventPresentation, root.activityPresentation))
    readonly property string primaryText: root.recording
        ? (I18n.tr("capture.screen_recording") || "REC")
        : (root.primaryPresentation
            ? (root.primaryPresentation.title || root.primaryPresentation.label || "")
            : (CenterNotchCoordinator.focusEnabled
                ? (CenterFocusStore.text || I18n.tr("menubar.center.focus_fallback"))
                : I18n.tr("menubar.center_notch.desktop")))
    readonly property string textTone: root.recording ? "danger"
        : (root.eventPresentation
            ? (root.eventPresentation.priority >= 70 ? "danger" : "primary")
            : "primary")
    readonly property string presentationKey: root.recording ? "recording"
        : (root.eventPresentation
            ? "event:" + (root.eventPresentation.source || "") + ":"
                + (root.eventPresentation.id || "") + ":"
                + (root.eventPresentation.kind || "")
            : (root.activityPresentation
                ? "activity:" + (root.activityPresentation.source || "") + ":"
                    + (root.activityPresentation.id || "")
                : "focus"))

    property string displayedText: ""
    property string displayedIcon: ""
    property string displayedTone: "primary"
    property string displayedPresentationKey: ""
    property bool presentationReady: false
    property bool presentationTransitionQueued: false

    property real forcedWidth: 0
    property real forcedHeight: Metrics.controlHeight
    property real trailingReservedWidth: 0
    readonly property real naturalWidth: Math.max(160, contentRow.implicitWidth
        + Metrics.spacingLarge * 2 + root.trailingReservedWidth)
    implicitWidth: Math.min(480, root.naturalWidth)
    width: root.forcedWidth > 0 ? root.forcedWidth : root.implicitWidth
    implicitHeight: root.forcedHeight
    height: root.forcedHeight
    clip: true
    opacity: root.notchOpen ? 0 : 1

    function publishTargetWidth(): void {
        CenterNotchCoordinator.setCompactWidth(root.implicitWidth);
    }

    onImplicitWidthChanged: root.publishTargetWidth()

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.reduced ? 0 : 140
            easing.type: Easing.OutCubic
        }
    }

    activeFocusOnTab: true

    function formatElapsed(seconds: real): string {
        const value = Math.max(0, Math.floor(Number(seconds) || 0));
        const minutes = Math.floor(value / 60);
        return String(minutes).padStart(2, "0") + ":" + String(value % 60).padStart(2, "0");
    }

    function activate(): void {
        root.publishTargetWidth();
        if (root.notchOpen) {
            CenterNotchCoordinator.close();
            return;
        }
        root.activateCore();
    }

    function activateCore(): void {
        root.publishTargetWidth();
        root.notchRequested(root.screen);
    }

    function queuePresentationTransition(): void {
        if (!root.presentationReady || root.presentationTransitionQueued)
            return;
        root.presentationTransitionQueued = true;
        Qt.callLater(root.applyPresentationTransition);
    }

    function applyPresentationTransition(): void {
        root.presentationTransitionQueued = false;
        if (root.displayedText === root.primaryText
                && root.displayedIcon === root.leadingIcon
                && root.displayedTone === root.textTone
                && root.displayedPresentationKey === root.presentationKey)
            return;

        const fullTransition = root.displayedPresentationKey !== root.presentationKey;
        outgoingRow.presentationText = root.displayedText;
        outgoingRow.presentationIcon = root.displayedIcon;
        outgoingRow.presentationTone = root.displayedTone;
        root.displayedText = root.primaryText;
        root.displayedIcon = root.leadingIcon;
        root.displayedTone = root.textTone;
        root.displayedPresentationKey = root.presentationKey;

        if (!fullTransition || Motion.reduced) {
            outgoingRow.opacity = 0;
            contentRow.opacity = 1;
            return;
        }

        presentationFade.restart();
    }

    onPrimaryTextChanged: root.queuePresentationTransition()
    onLeadingIconChanged: root.queuePresentationTransition()
    onTextToneChanged: root.queuePresentationTransition()
    onPresentationKeyChanged: root.queuePresentationTransition()

    Component.onCompleted: {
        root.displayedText = root.primaryText;
        root.displayedIcon = root.leadingIcon;
        root.displayedTone = root.textTone;
        root.displayedPresentationKey = root.presentationKey;
        root.presentationReady = true;
        root.publishTargetWidth();
    }

    readonly property bool isMedia: (root.activityPresentation?.source === "media"
        || root.displayedIcon === "music_note") && !root.recording
    readonly property bool isTimerOrJob: (root.activityPresentation?.source === "timer"
        || root.activityPresentation?.source === "job") && !root.recording
    readonly property bool isAgentAttention: root.primaryPresentation?.source === "agent" && !root.recording

    Rectangle {
        anchors.fill: parent
        radius: root.height / 2
        color: centerHover.hovered
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
            : "transparent"

        Behavior on color {
            ColorAnimation { duration: Motion.reduced ? 0 : Motion.fast }
        }
    }

    RowLayout {
        id: outgoingRow

        property string presentationText: ""
        property string presentationIcon: ""
        property string presentationTone: "primary"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Metrics.spacingLarge
        anchors.rightMargin: Metrics.spacingLarge + root.trailingReservedWidth
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: root.height / 2
        spacing: Metrics.spacingSmall
        opacity: 0

        Shared.Icon {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            name: outgoingRow.presentationIcon
            size: 18
            tone: "primary"
            visible: outgoingRow.presentationIcon.length > 0
            accessibleName: ""
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: outgoingRow.presentationText
            variant: "label"
            tone: outgoingRow.presentationTone
            strong: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }
    }

    RowLayout {
        id: contentRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Metrics.spacingLarge
        anchors.rightMargin: Metrics.spacingLarge + root.trailingReservedWidth
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: root.height / 2
        spacing: Metrics.spacingSmall

        Item {
            id: leadingItem
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            visible: root.recording || root.displayedIcon.length > 0 || root.isAgentAttention
            scale: Motion.reduced ? 1 : (centerTap.pressed ? 0.96
                : (centerHover.hovered ? 1.08 : 1))
            transform: Translate {
                y: !Motion.reduced && centerHover.hovered ? -1 : 0

                Behavior on y {
                    NumberAnimation { duration: Motion.reduced ? 0 : 140; easing.type: Easing.OutCubic }
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Motion.reduced ? 0 : 140
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.springDamped
                }
            }

            Item {
                id: aiBeacon
                anchors.centerIn: parent
                width: 18
                height: 18
                visible: root.isAgentAttention && !root.recording

                Rectangle {
                    id: aiAura
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    radius: 8
                    color: Theme.warning
                    opacity: 0.35

                    SequentialAnimation {
                        running: root.visible && root.isAgentAttention && !Motion.reduced
                        loops: 99999
                        ParallelAnimation {
                            NumberAnimation { target: aiAura; property: "scale"; from: 0.7; to: 1.35; duration: 800; easing.type: Easing.OutQuad }
                            NumberAnimation { target: aiAura; property: "opacity"; from: 0.45; to: 0.05; duration: 800; easing.type: Easing.OutQuad }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: aiAura; property: "scale"; from: 1.35; to: 0.7; duration: 700; easing.type: Easing.InQuad }
                            NumberAnimation { target: aiAura; property: "opacity"; from: 0.05; to: 0.45; duration: 700; easing.type: Easing.InQuad }
                        }
                    }
                }

                Shared.Icon {
                    anchors.centerIn: parent
                    name: "smart_toy"
                    size: 16
                    tone: "warning"
                }
            }

            Item {
                id: recordingBeacon
                anchors.centerIn: parent
                width: 18
                height: 18
                visible: root.recording

                Rectangle {
                    id: beaconAura
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    radius: 8
                    color: Theme.danger
                    opacity: 0.35

                    SequentialAnimation {
                        running: root.visible && recordingBeacon.visible && !Motion.reduced
                        loops: 99999
                        ParallelAnimation {
                            NumberAnimation { target: beaconAura; property: "scale"; from: 0.7; to: 1.35; duration: 800; easing.type: Easing.OutQuad }
                            NumberAnimation { target: beaconAura; property: "opacity"; from: 0.45; to: 0.05; duration: 800; easing.type: Easing.OutQuad }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: beaconAura; property: "scale"; from: 1.35; to: 0.7; duration: 700; easing.type: Easing.InQuad }
                            NumberAnimation { target: beaconAura; property: "opacity"; from: 0.05; to: 0.45; duration: 700; easing.type: Easing.InQuad }
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.danger
                }
            }

            Shared.Icon {
                id: leadingIconItem
                anchors.centerIn: parent
                visible: !root.recording && root.displayedIcon.length > 0

                readonly property bool focusMotion: name === "center_focus_strong"
                readonly property bool musicMotion: name === "music_note"
                readonly property bool notificationMotion: name === "notifications"
                    || name === "mark_email_unread"

                width: 18
                height: 18
                name: root.displayedIcon
                size: 18
                tone: root.isMedia ? "accent" : "primary"
                    accessibleName: root.displayedText
                transform: Translate { id: notificationLift }

                onFocusMotionChanged: {
                    if (!focusMotion)
                        scale = 1;
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: -2
                    anchors.rightMargin: -3
                    width: 9
                    height: 9
                    radius: 4.5
                    color: "#10b981"
                    visible: leadingIconItem.notificationMotion

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: "#ffffff"
                        font.pixelSize: 7
                        font.bold: true
                    }
                }
                onMusicMotionChanged: {
                    if (!musicMotion)
                        rotation = 0;
                }
                onNotificationMotionChanged: {
                    if (!notificationMotion) {
                        rotation = 0;
                        notificationLift.y = 0;
                    }
                }

                SequentialAnimation {
                    running: leadingIconItem.visible && leadingIconItem.focusMotion
                    loops: 3

                    NumberAnimation {
                        target: leadingIconItem
                        property: "scale"
                        from: 1
                        to: 1.14
                        duration: 520
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: leadingIconItem
                        property: "scale"
                        from: 1.14
                        to: 1
                        duration: 520
                        easing.type: Easing.InOutSine
                    }
                }

                NumberAnimation {
                    target: leadingIconItem
                    property: "rotation"
                    running: leadingIconItem.visible && leadingIconItem.musicMotion
                    from: 0
                    to: 360
                    duration: 4200
                    easing.type: Easing.InOutSine
                }

                SequentialAnimation {
                    running: root.visible && leadingIconItem.visible && leadingIconItem.notificationMotion
                    loops: 99999

                    ParallelAnimation {
                        NumberAnimation {
                            target: leadingIconItem
                            property: "rotation"
                            from: 0
                            to: -12
                            duration: 90
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: notificationLift
                            property: "y"
                            from: 0
                            to: -2
                            duration: 90
                            easing.type: Easing.OutQuad
                        }
                    }
                    NumberAnimation {
                        target: leadingIconItem
                        property: "rotation"
                        from: -12
                        to: 12
                        duration: 150
                        easing.type: Easing.InOutQuad
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: leadingIconItem
                            property: "rotation"
                            from: 12
                            to: 0
                            duration: 110
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: notificationLift
                            property: "y"
                            from: -2
                            to: 0
                            duration: 110
                            easing.type: Easing.OutBounce
                        }
                    }
                    PauseAnimation { duration: 2400 }
                }
            }
        }

        Shared.TextLabel {
            id: primaryLabel
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.displayedText
            variant: "label"
            tone: root.displayedTone
            strong: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }

        Row {
            id: dynamicWaveform
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            visible: root.isMedia

            Repeater {
                model: [
                    { minH: 4, maxH: 14, dur: 420 },
                    { minH: 6, maxH: 16, dur: 320 },
                    { minH: 3, maxH: 12, dur: 480 }
                ]

                Rectangle {
                    id: waveBar
                    required property var modelData
                    width: 2.5
                    height: modelData.minH
                    radius: 1.25
                    color: Theme.accent

                    SequentialAnimation {
                        running: root.visible && dynamicWaveform.visible && !Motion.reduced
                        loops: 99999
                        NumberAnimation {
                            target: waveBar
                            property: "height"
                            from: waveBar.modelData.minH
                            to: waveBar.modelData.maxH
                            duration: waveBar.modelData.dur
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: waveBar
                            property: "height"
                            from: waveBar.modelData.maxH
                            to: waveBar.modelData.minH
                            duration: waveBar.modelData.dur
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }

        Rectangle {
            id: recordingBadge
            Layout.alignment: Qt.AlignVCenter
            visible: root.recording
            Layout.preferredHeight: 18
            radius: 9
            Layout.preferredWidth: recordingTimerLabel.implicitWidth + 10
            color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.2)
            border.width: 1
            border.color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.4)

            Shared.TextLabel {
                id: recordingTimerLabel
                anchors.centerIn: parent
                text: root.formatElapsed(ScreenRecordService.elapsedSeconds)
                variant: "caption"
                tone: "danger"
                strong: true
            }
        }

        Rectangle {
            id: progressBadge
            Layout.alignment: Qt.AlignVCenter
            visible: root.isTimerOrJob && root.activityPresentation?.progress > 0
            Layout.preferredHeight: 18
            radius: 9
            Layout.preferredWidth: progressLabel.implicitWidth + 10
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
            border.width: 1
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)

            Shared.TextLabel {
                id: progressLabel
                anchors.centerIn: parent
                text: Math.round(root.activityPresentation?.progress || 0) + "%"
                variant: "caption"
                tone: "accent"
                strong: true
            }
        }

    }

    ParallelAnimation {
        id: presentationFade

        NumberAnimation {
            target: outgoingRow
            property: "opacity"
            from: 1
            to: 0
            duration: 160
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: contentRow
            property: "opacity"
            from: 0
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    CenterPigMascot {
        visible: Preferences.bar.mascotEnabled !== false
            && !root.recording && root.primaryPresentation === null
    }

    HoverHandler {
        id: centerHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: centerTap
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.activate();
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root.settingsRequested(root.screen)
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter) {
            root.activate();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr("menubar.center_notch.accessible") + ": " + root.primaryText
    Accessible.focusable: true
}
