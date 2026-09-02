pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Bar.notch
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center
import qs.Titonium.Services.Capture
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "CenterActivationRules.js" as CenterActivationRules
import "CenterPresentationRules.js" as CenterPresentationRules

FocusScope {
    id: root

    required property var screen
    signal notchRequested(var screen)
    signal sourceRequested(var screen, string intent)

    readonly property var eventPresentation: CenterAttentionService.presentation
    readonly property var activityPresentation: CenterActivityService.presentation
    readonly property var primaryPresentation: root.eventPresentation || root.activityPresentation
    readonly property bool recording: ScreenRecordService.recording
    readonly property bool notchOpen: CenterNotchCoordinator.ownerScreenName === root.screen.name
    readonly property string recordingText: root.recording
        ? "REC • " + root.formatElapsed(ScreenRecordService.elapsedSeconds) : ""
    readonly property string leadingIcon: root.recording ? "screen_record"
        : CenterPresentationRules.leadingIcon(root.eventPresentation, root.activityPresentation)
    readonly property string primaryText: root.recording ? root.recordingText
        : (root.primaryPresentation ? root.primaryPresentation.title
            : (CenterFocusStore.text || I18n.tr("menubar.center.focus_fallback")))
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
    property bool sizeMorphEnabled: false

    readonly property real naturalWidth: contentRow.implicitWidth + Metrics.spacingLarge * 2
    implicitWidth: Math.min(480, root.naturalWidth)
    implicitHeight: Metrics.controlHeight
    scale: root.notchOpen ? 0.97 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Motion.reduced ? 0 : 160
            easing.type: Easing.OutCubic
        }
    }

    Behavior on implicitWidth {
        enabled: root.sizeMorphEnabled
        NumberAnimation {
            duration: Motion.reduced ? 0 : 330
            easing.bezierCurve: [0.34, 1.22, 0.64, 1, 1, 1]
        }
    }

    Behavior on implicitHeight {
        enabled: root.sizeMorphEnabled
        NumberAnimation {
            duration: Motion.reduced ? 0 : 330
            easing.bezierCurve: [0.34, 1.22, 0.64, 1, 1, 1]
        }
    }

    activeFocusOnTab: true

    function formatElapsed(seconds: real): string {
        const value = Math.max(0, Math.floor(Number(seconds) || 0));
        const minutes = Math.floor(value / 60);
        return String(minutes).padStart(2, "0") + ":" + String(value % 60).padStart(2, "0");
    }

    function activate(): void {
        const source = root.primaryPresentation?.source || "";
        const intent = CenterActivationRules.intent(source);
        if (intent === "open-center")
            root.notchRequested(root.screen);
        else
            root.sourceRequested(root.screen, intent);
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
        root.sizeMorphEnabled = fullTransition && !Motion.reduced;
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
    }

    Shared.Surface {
        anchors.fill: parent
        tone: centerHover.hovered ? "interactive" : "elevated"
        radius: root.implicitHeight / 2
        outlined: false
    }

    RowLayout {
        id: outgoingRow

        property string presentationText: ""
        property string presentationIcon: ""
        property string presentationTone: "primary"

        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingLarge
        anchors.rightMargin: Metrics.spacingLarge
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
            Layout.maximumWidth: 320
            text: outgoingRow.presentationText
            variant: "label"
            tone: outgoingRow.presentationTone
            strong: true
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingLarge
        anchors.rightMargin: Metrics.spacingLarge
        spacing: Metrics.spacingSmall

        Shared.Icon {
            id: leadingIconItem

            readonly property bool focusMotion: name === "center_focus_strong"
            readonly property bool musicMotion: name === "music_note"
            readonly property bool notificationMotion: name === "notifications"
                || name === "mark_email_unread"

            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            name: root.displayedIcon
            size: 18
            tone: "primary"
            visible: root.displayedIcon.length > 0
            accessibleName: root.displayedText
            transform: Translate { id: notificationLift }

            onFocusMotionChanged: {
                if (!focusMotion)
                    scale = 1;
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
                running: leadingIconItem.visible && leadingIconItem.notificationMotion
                loops: 2

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
                PauseAnimation { duration: 140 }
            }
        }

        Shared.TextLabel {
            id: primaryLabel
            Layout.maximumWidth: 320
            text: root.displayedText
            variant: "label"
            tone: root.displayedTone
            strong: true
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
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
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.activate();
        }
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
