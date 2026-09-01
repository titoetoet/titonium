pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
    readonly property string recordingText: root.recording
        ? "REC • " + root.formatElapsed(ScreenRecordService.elapsedSeconds) : ""
    readonly property string leadingIcon: root.recording ? "screen_record"
        : CenterPresentationRules.leadingIcon(root.eventPresentation, root.activityPresentation)
    readonly property string primaryText: root.recording ? root.recordingText
        : (root.primaryPresentation
            ? root.primaryPresentation.title
            : (CenterFocusStore.text || I18n.tr("menubar.center.focus_fallback")))
    readonly property string textTone: root.recording ? "danger"
        : (root.eventPresentation
            ? (root.eventPresentation.priority >= 70 ? "danger" : "primary")
            : (root.activityPresentation ? "primary" : "secondary"))

    implicitWidth: Math.min(480, contentRow.implicitWidth + Metrics.spacingLarge * 2)
    implicitHeight: Metrics.controlHeight
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

    Shared.Surface {
        anchors.fill: parent
        tone: centerHover.hovered ? "interactive" : "elevated"
        radius: Metrics.radiusLarge
        outlined: false
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingLarge
        anchors.rightMargin: Metrics.spacingLarge
        spacing: Metrics.spacingSmall

        Shared.Icon {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            name: root.leadingIcon
            size: 18
            tone: "primary"
            visible: root.leadingIcon.length > 0
            accessibleName: root.primaryText
        }

        Shared.TextLabel {
            id: primaryLabel
            Layout.maximumWidth: 320
            text: root.primaryText
            variant: "label"
            tone: root.textTone
            strong: root.primaryPresentation !== null
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }
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
